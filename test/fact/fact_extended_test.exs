defmodule FactExtendedTest do
  use ExUnit.Case

  @moduletag :capture_log

  setup_all do
    Code.ensure_loaded!(Fact.EventDataIndexer)
    path = TestHelper.create_db("fact_ext_")
    on_exit(fn -> TestHelper.rm_rf(path) end)
    {:ok, db} = Fact.open(path)

    events = [
      %{stream_id: "stream-1", type: "TypeA", data: %{"name" => "Alice"}, tags: ["t1"]},
      %{stream_id: "stream-1", type: "TypeB", data: %{"name" => "Bob"}, tags: ["t2"]},
      %{stream_id: "stream-2", type: "TypeA", data: %{"name" => "Charlie"}, tags: ["t1", "t2"]},
      %{stream_id: "stream-2", type: "TypeC", data: %{"name" => "Dave"}}
    ]

    {:ok, _ids} = Fact.append(db, events)
    TestHelper.subscribe_and_wait(db, 5)

    {:ok, db: db}
  end

  describe "open/2" do
    test "returns error for nonexistent database" do
      assert {:error, :database_not_found} =
               Fact.open("does/not/exist/#{System.unique_integer()}")
    end
  end

  describe "ready?/1" do
    test "returns false for unknown database" do
      assert Fact.ready?("nonexistent_db_name") == false
    end
  end

  describe "read/3 sources" do
    test "read :none returns empty", %{db: db} do
      events = Fact.read(db, :none) |> Enum.to_list()
      assert events == []
    end

    test "read {:stream, id} returns only that stream's events", %{db: db} do
      events = Fact.read(db, {:stream, "stream-1"}) |> Enum.to_list()

      assert length(events) == 2
      assert Enum.all?(events, fn e -> e["stream_id"] == "stream-1" end)
    end

    test "read {:query, :all} returns all events", %{db: db} do
      events = Fact.read(db, {:query, :all}) |> Enum.to_list()

      assert length(events) >= 4
    end

    test "read {:query, :none} returns no events", %{db: db} do
      events = Fact.read(db, {:query, :none}) |> Enum.to_list()

      assert events == []
    end

    test "read {:query, query_item} with a single QueryItem", %{db: db} do
      query_item = Fact.QueryItem.types("TypeA")
      events = Fact.read(db, {:query, query_item}) |> Enum.to_list()

      assert length(events) >= 1
      assert Enum.all?(events, fn e -> e["event_type"] == "TypeA" end)
    end

    test "read {:query, [query_items]} with a list of QueryItems", %{db: db} do
      query_items = [Fact.QueryItem.types("TypeA"), Fact.QueryItem.types("TypeB")]
      events = Fact.read(db, {:query, query_items}) |> Enum.to_list()

      assert length(events) >= 2
    end

    test "read {:query, query_fun} with a function", %{db: db} do
      {:ok, query_fun} = Fact.Query.from_types(["TypeA"])
      events = Fact.read(db, {:query, query_fun}) |> Enum.to_list()

      assert length(events) >= 1
    end
  end

  describe "read/3 with index source" do
    test "read {:index, indexer_id, index} returns matching events", %{db: db} do
      events =
        Fact.read(db, {:index, {Fact.EventTagsIndexer, nil}, "t1"}) |> Enum.to_list()

      assert length(events) >= 1
      assert Enum.all?(events, fn e -> "t1" in (e["event_tags"] || []) end)
    end
  end

  describe "read/3 options" do
    test "direction: :backward reads in reverse", %{db: db} do
      events = Fact.read(db, :all, direction: :backward) |> Enum.to_list()

      positions = Enum.map(events, & &1["store_position"])
      assert positions == Enum.sort(positions, :desc)
    end

    test "count: limits results", %{db: db} do
      events = Fact.read(db, :all, count: 2) |> Enum.to_list()

      assert length(events) == 2
    end

    test "position: starts from given position", %{db: db} do
      events = Fact.read(db, :all, position: 3) |> Enum.to_list()

      positions = Enum.map(events, & &1["store_position"])
      assert Enum.all?(positions, &(&1 > 3))
    end

    test "result: :record returns {record_id, event} tuples", %{db: db} do
      results = Fact.read(db, :all, result: :record, count: 1) |> Enum.to_list()

      assert [{record_id, event}] = results
      assert is_binary(record_id)
      assert is_map(event)
    end

    test "result: :record_id returns record IDs only", %{db: db} do
      results = Fact.read(db, :all, result: :record_id, count: 2) |> Enum.to_list()

      assert length(results) == 2
      assert Enum.all?(results, &is_binary/1)
    end

    test "eager: false returns a Stream", %{db: db} do
      result = Fact.read(db, :all, eager: false)

      assert %Stream{} = result
      events = Enum.to_list(result)
      assert length(events) >= 4
    end
  end

  describe "append/4 with append_condition" do
    test "append without condition succeeds", %{db: db} do
      assert {:ok, _pos} = Fact.append(db, [%{stream_id: "cond-s", type: "X", data: %{}}])
    end

    test "append with nil condition succeeds", %{db: db} do
      assert {:ok, _pos} = Fact.append(db, [%{stream_id: "cond-nil", type: "X", data: %{}}], nil)
    end
  end

  describe "append_stream/5" do
    test "appends to a stream with :any expectation", %{db: db} do
      stream = "ext-stream-#{System.unique_integer([:positive])}"
      events = [%{type: "StreamEvent", data: %{"v" => 1}}]

      assert {:ok, 1} = Fact.append_stream(db, events, stream, :any)
    end

    test "appends to a stream with :none expectation for new stream", %{db: db} do
      stream = "ext-new-#{System.unique_integer([:positive])}"
      events = [%{type: "StreamEvent", data: %{}}]

      assert {:ok, 1} = Fact.append_stream(db, events, stream, :none)
    end

    test "appends to a stream with :exists expectation", %{db: db} do
      stream = "ext-exists-#{System.unique_integer([:positive])}"
      Fact.append_stream(db, [%{type: "Init", data: %{}}], stream)

      assert {:ok, 2} = Fact.append_stream(db, [%{type: "Second", data: %{}}], stream, :exists)
    end

    test "appends to a stream with integer expectation", %{db: db} do
      stream = "ext-int-#{System.unique_integer([:positive])}"
      {:ok, 1} = Fact.append_stream(db, [%{type: "Init", data: %{}}], stream)

      assert {:ok, 2} = Fact.append_stream(db, [%{type: "Second", data: %{}}], stream, 1)
    end

    test "single map event is wrapped automatically", %{db: db} do
      stream = "ext-single-#{System.unique_integer([:positive])}"

      assert {:ok, 1} = Fact.append_stream(db, %{type: "SingleEvent", data: %{}}, stream)
    end
  end

  describe "subscribe/3" do
    test "subscribe to :all and receive live events", %{db: db} do
      {:ok, _sub} = Fact.subscribe(db, :all, position: :end, subscriber: self())

      assert_receive :caught_up, 5_000

      {:ok, _} =
        Fact.append(db, [%{stream_id: "sub-stream", type: "SubTest", data: %{}}])

      assert_receive {:record, _}, 5_000
    end

    test "subscribe to a stream", %{db: db} do
      {:ok, _sub} =
        Fact.subscribe(db, {:stream, "stream-1"}, position: :start, subscriber: self())

      events = collect_until_caught_up(5_000)
      assert length(events) >= 1
    end

    test "subscribe with a single QueryItem wraps to list", %{db: db} do
      query = Fact.QueryItem.types("TypeA")
      {:ok, _sub} = Fact.subscribe(db, {:query, query}, position: :end, subscriber: self())

      assert_receive :caught_up, 5_000
    end
  end

  describe "when_ready/2" do
    test "sends ready message for running database" do
      path = TestHelper.create_db("ready_test_")
      on_exit(fn -> TestHelper.rm_rf(path) end)

      # Get the database name from the path
      db_name = Path.basename(path)

      {:ok, _db} = Fact.open(path)
      Fact.when_ready(db_name, timeout: 5_000)

      assert_receive {:database_ready, %{database_name: ^db_name}}, 5_000
    end
  end

  defp collect_until_caught_up(timeout, acc \\ []) do
    receive do
      :caught_up -> Enum.reverse(acc)
      {:record, record} -> collect_until_caught_up(timeout, [record | acc])
    after
      timeout -> Enum.reverse(acc)
    end
  end
end
