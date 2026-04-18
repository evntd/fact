defmodule Fact.CustomIndexersTest do
  @moduledoc false

  use ExUnit.Case

  @moduletag :capture_log

  defmodule BreedIndexer do
    use Fact.EventIndexer

    @impl true
    def index_event(schema, event, _opts) do
      unless is_nil(breed = Map.get(event[schema.event_data], "breed")),
        do: to_string(breed)
    end
  end

  describe "custom indexers via Fact.open/2" do
    setup do
      path = TestHelper.create_db("custom_indexer_")
      on_exit(fn -> TestHelper.rm_rf(path) end)

      {:ok, db} =
        Fact.open(path,
          indexers: [
            BreedIndexer,
            {Fact.EventDataIndexer, key: "name"}
          ]
        )

      {:ok, db: db}
    end

    test "custom indexer processes are running", %{db: db} do
      assert [{pid, _}] =
               Registry.lookup(Fact.Registry.registry(db), {BreedIndexer, nil})

      assert Process.alive?(pid)
    end

    test "EventDataIndexer with key is running", %{db: db} do
      assert [{pid, _}] =
               Registry.lookup(Fact.Registry.registry(db), {Fact.EventDataIndexer, "name"})

      assert Process.alive?(pid)
    end

    test "custom indexer indexes events", %{db: db} do
      event = %{type: "pet_adopted", data: %{name: "Bandit", breed: "Lab"}}
      {:ok, position} = Fact.append(db, event)

      TestHelper.subscribe_and_wait(db, position)

      records = Fact.read(db, {:index, {BreedIndexer, nil}, "Lab"})
      assert length(records) == 1
      assert hd(records)["event_data"]["breed"] == "Lab"
    end

    test "EventDataIndexer via config indexes events", %{db: db} do
      event = %{type: "pet_adopted", data: %{name: "Snicker", breed: "Mutt"}}
      {:ok, position} = Fact.append(db, event)

      TestHelper.subscribe_and_wait(db, position)

      records = Fact.read(db, {:index, {Fact.EventDataIndexer, "name"}, "Snicker"})
      assert length(records) == 1
      assert hd(records)["event_data"]["name"] == "Snicker"
    end
  end
end
