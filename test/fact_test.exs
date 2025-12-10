defmodule FactTest do
  use ExUnit.Case, async: true

  alias Fact

  @moduletag :capture_log

  doctest Fact

  setup_all do
    path = "test_fact_" <> (DateTime.utc_now() |> DateTime.to_unix() |> to_string())
    instance = path |> String.to_atom()

    on_exit(fn -> File.rm_rf!(path) end)

    {:ok, _pid} = Fact.start_link(instance)

    {:ok, instance: instance}
  end

  describe "Fact.append/*" do
    test "should fail when given invalid instance" do
      assert {:error, :invalid_instance} == Fact.append("invalid", %{type: "TestEvent"})
    end

    test "should fail when events are not a list", %{instance: db} do
      assert {:error, :invalid_event_list} == Fact.append(db, nil)
    end

    test "should fail when events are not a list of maps", %{instance: db} do
      assert {:error, :invalid_events} == Fact.append(db, [1, 2, 3])
    end

    test "should fail when fail_if_match is not a function", %{instance: db} do
      assert {:error, :invalid_fail_if_match_query} ==
               Fact.append(db, %{type: "TestEvent"}, :not_a_function)
    end

    test "should fail when fail_if_match has wrong arity", %{instance: db} do
      assert {:error, :invalid_fail_if_match_query} ==
               Fact.append(db, %{type: "TestEvent"}, fn x, y -> x + y end)
    end

    test "should fail when after_position is not an integer", %{instance: db} do
      assert {:error, :invalid_after_position} ==
               Fact.append(db, %{type: "TestEvent"}, Fact.Query.from_none(), "0")
    end

    test "should fail when after_position is negative", %{instance: db} do
      assert {:error, :invalid_after_position} ==
               Fact.append(db, %{type: "TestEvent"}, Fact.Query.from_none(), -1)
    end

    test "should append an event with no conditions", %{instance: db} do
      assert {:ok, _} = Fact.append(db, %{type: "TestEvent"})
    end

    test "should append an event with a fail_if_match query and no after position", %{
      instance: db
    } do
      {:ok, query} = Fact.Query.from_tags("test:t1")
      assert {:ok, _} = Fact.append(db, %{type: "TestEvent", tags: ["test:t1"]}, query)
    end

    test "should append an event with a fail_if_match query and after position", %{instance: db} do
      {:ok, query} = Fact.Query.from_tags("test:t2")
      assert {:ok, _} = Fact.append(db, %{type: "TestEvent", tags: ["test:t2"]}, query, 1)
    end

    test "should fail when fail_if_match query contains events", %{instance: db} do
      {:ok, query} = Fact.Query.from_tags("test:t3")

      assert {:ok, position} = Fact.append(db, %{type: "TestEvent", tags: ["test:t3"]}, query),
             "setup for consistency error"

      assert {:error, {:concurrency, [expected: 0, actual: position]}} ==
               Fact.append(db, %{type: "TestEvent", tags: ["test:t3"]}, query)
    end

    test "should fail when fail_if_match query contains events after position", %{instance: db} do
      {:ok, query} = Fact.Query.from_tags("test:t4")

      assert {:ok, position} = Fact.append(db, %{type: "TestEvent", tags: ["test:t4"]}, query),
             "setup for consistency error"

      assert {:error, {:concurrency, [expected: position - 1, actual: position]}} ==
               Fact.append(db, %{type: "TestEvent", tags: ["test:t4"]}, query, position - 1)
    end

    test "should append an event when fail_if_match query contains no events after position", %{
      instance: db
    } do
      {:ok, query} = Fact.Query.from_tags("test:t5")

      assert {:ok, position} = Fact.append(db, %{type: "TestEvent", tags: ["test:t5"]}, query),
             "setup for consistency error"

      assert {:ok, _} = Fact.append(db, %{type: "TestEvent", tags: ["test:t5"]}, query, position)
    end
  end

  defmodule TestDb do
    use Fact, instance: :test_using_fact
  end

  setup_all do
    path = TestDb.instance() |> Atom.to_string()
    on_exit(fn -> File.rm_rf!(path) end)

    {:ok, _pid} = TestDb.start_link()

    :ok
  end

  describe "using Fact.instance" do
    test "should return the instance name" do
      assert :test_using_fact == TestDb.instance()
    end
  end

  describe "using Fact.append/*" do
    test "should fail when events are not a list" do
      assert {:error, :invalid_event_list} == TestDb.append(nil)
    end

    test "should fail when events are not a list of maps" do
      assert {:error, :invalid_events} == TestDb.append([1, 2, 3])
    end

    test "should fail when fail_if_match is not a function" do
      assert {:error, :invalid_fail_if_match_query} ==
               TestDb.append(%{type: "TestEvent"}, :not_a_function)
    end

    test "should fail when fail_if_match has wrong arity" do
      assert {:error, :invalid_fail_if_match_query} ==
               TestDb.append(%{type: "TestEvent"}, fn x, y -> x + y end)
    end

    test "should fail when after_position is not an integer" do
      assert {:error, :invalid_after_position} ==
               TestDb.append(%{type: "TestEvent"}, Fact.Query.from_none(), "0")
    end

    test "should fail when after_position is negative" do
      assert {:error, :invalid_after_position} ==
               TestDb.append(%{type: "TestEvent"}, Fact.Query.from_none(), -1)
    end

    test "should append an event with no conditions" do
      assert {:ok, _} = TestDb.append(%{type: "TestEvent"})
    end

    test "should append an event with a fail_if_match query and no after position" do
      {:ok, query} = Fact.Query.from_tags("test:t1")
      assert {:ok, _} = TestDb.append(%{type: "TestEvent", tags: ["test:t1"]}, query)
    end

    test "should append an event with a fail_if_match query and after position" do
      {:ok, query} = Fact.Query.from_tags("test:t2")
      assert {:ok, _} = TestDb.append(%{type: "TestEvent", tags: ["test:t2"]}, query, 1)
    end

    test "should fail when fail_if_match query contains events" do
      {:ok, query} = Fact.Query.from_tags("test:t3")

      assert {:ok, position} = TestDb.append(%{type: "TestEvent", tags: ["test:t3"]}, query),
             "setup for consistency error"

      assert {:error, {:concurrency, [expected: 0, actual: position]}} ==
               TestDb.append(%{type: "TestEvent", tags: ["test:t3"]}, query)
    end

    test "should fail when fail_if_match query contains events after position" do
      {:ok, query} = Fact.Query.from_tags("test:t4")

      assert {:ok, position} = TestDb.append(%{type: "TestEvent", tags: ["test:t4"]}, query),
             "setup for consistency error"

      assert {:error, {:concurrency, [expected: position - 1, actual: position]}} ==
               TestDb.append(%{type: "TestEvent", tags: ["test:t4"]}, query, position - 1)
    end

    test "should append an event when fail_if_match query contains no events after position" do
      {:ok, query} = Fact.Query.from_tags("test:t5")

      assert {:ok, position} = TestDb.append(%{type: "TestEvent", tags: ["test:t5"]}, query),
             "setup for consistency error"

      assert {:ok, _} = TestDb.append(%{type: "TestEvent", tags: ["test:t5"]}, query, position)
    end
  end
end
