defmodule FactTest do
  use ExUnit.Case, async: true

  alias Fact

  @moduletag capture_log: true

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
      {:ok, position} = Fact.append(db, %{type: "TestEvent", tags: ["test:t3"]}, query)

      assert {:error, %Fact.ConcurrencyError{source: :all, expected: 0, actual: position}} ==
               Fact.append(db, %{type: "TestEvent", tags: ["test:t3"]}, query)
    end

    test "should fail when fail_if_match query contains events after position", %{instance: db} do
      {:ok, query} = Fact.Query.from_tags("test:t4")
      {:ok, position} = Fact.append(db, %{type: "TestEvent", tags: ["test:t4"]}, query)
      expectation = position - 1

      assert {:error,
              %Fact.ConcurrencyError{source: :all, expected: expectation, actual: position}} ==
               Fact.append(db, %{type: "TestEvent", tags: ["test:t4"]}, query, expectation)
    end

    test "should append an event when fail_if_match query contains no events after position", %{
      instance: db
    } do
      {:ok, query} = Fact.Query.from_tags("test:t5")
      {:ok, position} = Fact.append(db, %{type: "TestEvent", tags: ["test:t5"]}, query)
      assert {:ok, _} = Fact.append(db, %{type: "TestEvent", tags: ["test:t5"]}, query, position)
    end
  end

  @test_event %{type: "TestEvent"}

  describe "Fact.append_stream/*" do
    test "should fail when given invalid instance" do
      assert {:error, :invalid_instance} ==
               Fact.append_stream("invalid", @test_event, "TestStream")
    end

    test "should fail when events are not a list", %{instance: db} do
      assert {:error, :invalid_event_list} == Fact.append_stream(db, nil, "TestStream")
    end

    test "should fail when events are not a list of maps", %{instance: db} do
      assert {:error, :invalid_events} == Fact.append_stream(db, [1, 2, 3], "TestStream")
    end

    test "should fail when event stream is not a string", %{instance: db} do
      assert {:error, :invalid_event_stream} ==
               Fact.append_stream(db, @test_event, :not_valid_stream)
    end

    test "should fail when expected position is not valid atom", %{instance: db} do
      assert {:error, :invalid_expected_position} ==
               Fact.append_stream(db, @test_event, "TestStream", :invalid)
    end

    test "should fail when expected position is not an integer", %{instance: db} do
      assert {:error, :invalid_expected_position} ==
               Fact.append_stream(db, @test_event, "TestStream", 1.2)
    end

    test "should append event to stream given no expected position", %{instance: db} do
      assert {:ok, 1} == Fact.append_stream(db, @test_event, "test_stream-1")
    end

    test "should append event to stream given :any expected position", %{instance: db} do
      assert {:ok, 1} == Fact.append_stream(db, @test_event, "test_stream-2", :any)
    end

    test "should append event to existing stream given :any expected", %{instance: db} do
      Fact.append_stream(db, @test_event, "test_stream-2b", :any)
      assert {:ok, 2} == Fact.append_stream(db, @test_event, "test_stream-2b", :any)
    end

    test "should append event to new stream given :none expected", %{instance: db} do
      assert {:ok, 1} == Fact.append_stream(db, @test_event, "test_stream-3", :none)
    end

    test "should fail to append event given stream exists and :none expected", %{instance: db} do
      assert {:ok, 1} == Fact.append_stream(db, @test_event, "test_stream-4", :none)

      assert {:error, %Fact.ConcurrencyError{source: "test_stream-4", expected: :none, actual: 1}} ==
               Fact.append_stream(db, @test_event, "test_stream-4", :none)
    end

    test "should fail to append event to new stream given :exists expected", %{instance: db} do
      assert {:error,
              %Fact.ConcurrencyError{source: "test_stream-5", expected: :exists, actual: 0}} ==
               Fact.append_stream(db, @test_event, "test_stream-5", :exists)
    end

    test "should append event to existing stream given :exists expected", %{instance: db} do
      Fact.append_stream(db, @test_event, "test_stream-6")
      assert {:ok, 2} == Fact.append_stream(db, @test_event, "test_stream-6", :exists)
    end

    test "should append event to new stream given 0 as expected position", %{instance: db} do
      assert {:ok, 1} == Fact.append_stream(db, @test_event, "test_stream-7", 0)
    end

    test "should append event to new stream given last as expected position", %{instance: db} do
      {:ok, position} =
        Fact.append_stream(db, [@test_event, @test_event, @test_event], "test_stream-8", 0)

      assert {:ok, 4} == Fact.append_stream(db, @test_event, "test_stream-8", position)
    end

    test "should fail to append event when given expected position before actual position", %{
      instance: db
    } do
      {:ok, position} =
        Fact.append_stream(db, [@test_event, @test_event, @test_event], "test_stream-9", 0)

      assert {:error,
              %Fact.ConcurrencyError{source: "test_stream-9", expected: 1, actual: position}} ==
               Fact.append_stream(db, @test_event, "test_stream-9", 1)
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
      {:ok, query} = Fact.Query.from_tags("using_test:t1")
      assert {:ok, _} = TestDb.append(%{type: "TestEvent", tags: ["using_test:t1"]}, query)
    end

    test "should append an event with a fail_if_match query and after position" do
      {:ok, query} = Fact.Query.from_tags("using_test:t2")
      assert {:ok, _} = TestDb.append(%{type: "TestEvent", tags: ["using_test:t2"]}, query, 1)
    end

    test "should fail when fail_if_match query contains events" do
      {:ok, query} = Fact.Query.from_tags("using_test:t3")

      assert {:ok, position} =
               TestDb.append(%{type: "TestEvent", tags: ["using_test:t3"]}, query),
             "setup for consistency error"

      assert {:error, %Fact.ConcurrencyError{source: :all, expected: 0, actual: position}} ==
               TestDb.append(%{type: "TestEvent", tags: ["using_test:t3"]}, query)
    end

    test "should fail when fail_if_match query contains events after position" do
      {:ok, query} = Fact.Query.from_tags("using_test:t4")
      {:ok, position} = TestDb.append(%{type: "TestEvent", tags: ["using_test:t4"]}, query)

      expectation = position - 1

      assert {:error,
              %Fact.ConcurrencyError{source: :all, expected: expectation, actual: position}} ==
               TestDb.append(%{type: "TestEvent", tags: ["using_test:t4"]}, query, expectation)
    end

    test "should append an event when fail_if_match query contains no events after position" do
      {:ok, query} = Fact.Query.from_tags("using_test:t5")

      {:ok, position} = TestDb.append(%{type: "TestEvent", tags: ["using_test:t5"]}, query)

      assert {:ok, _} =
               TestDb.append(%{type: "TestEvent", tags: ["using_test:t5"]}, query, position)
    end
  end

  describe "using Fact.append_stream/*" do
    test "should fail when events are not a list" do
      assert {:error, :invalid_event_list} == TestDb.append_stream(nil, "TestStream")
    end

    test "should fail when events are not a list of maps" do
      assert {:error, :invalid_events} == TestDb.append_stream([1, 2, 3], "TestStream")
    end

    test "should fail when event stream is not a string" do
      assert {:error, :invalid_event_stream} ==
               TestDb.append_stream(@test_event, :not_valid_stream)
    end

    test "should fail when expected position is not valid atom" do
      assert {:error, :invalid_expected_position} ==
               TestDb.append_stream(@test_event, "TestStream", :invalid)
    end

    test "should fail when expected position is not an integer" do
      assert {:error, :invalid_expected_position} ==
               TestDb.append_stream(@test_event, "TestStream", 1.2)
    end

    test "should append event to stream given no expected position" do
      assert {:ok, 1} == TestDb.append_stream(@test_event, "test_stream-1")
    end

    test "should append event to stream given :any expected position" do
      assert {:ok, 1} == TestDb.append_stream(@test_event, "test_stream-2", :any)
    end

    test "should append event to existing stream given :any expected" do
      TestDb.append_stream(@test_event, "test_stream-2b", :any)
      assert {:ok, 2} == TestDb.append_stream(@test_event, "test_stream-2b", :any)
    end

    test "should append event to new stream given :none expected" do
      assert {:ok, 1} == TestDb.append_stream(@test_event, "test_stream-3", :none)
    end

    test "should fail to append event given stream exists and :none expected" do
      assert {:ok, 1} == TestDb.append_stream(@test_event, "test_stream-4", :none)

      assert {:error, %Fact.ConcurrencyError{source: "test_stream-4", expected: :none, actual: 1}} ==
               TestDb.append_stream(@test_event, "test_stream-4", :none)
    end

    test "should fail to append event to new stream given :exists expected" do
      assert {:error,
              %Fact.ConcurrencyError{source: "test_stream-5", expected: :exists, actual: 0}} ==
               TestDb.append_stream(@test_event, "test_stream-5", :exists)
    end

    test "should append event to existing stream given :exists expected" do
      TestDb.append_stream(@test_event, "test_stream-6")
      assert {:ok, 2} == TestDb.append_stream(@test_event, "test_stream-6", :exists)
    end

    test "should append event to new stream given 0 as expected position" do
      assert {:ok, 1} == TestDb.append_stream(@test_event, "test_stream-7", 0)
    end

    test "should append event to new stream given last as expected position" do
      {:ok, position} =
        TestDb.append_stream([@test_event, @test_event, @test_event], "test_stream-8", 0)

      assert {:ok, 4} == TestDb.append_stream(@test_event, "test_stream-8", position)
    end

    test "should fail to append event when given expected position before actual position" do
      {:ok, position} =
        TestDb.append_stream([@test_event, @test_event, @test_event], "test_stream-9", 0)

      assert {:error,
              %Fact.ConcurrencyError{source: "test_stream-9", expected: 1, actual: position}} ==
               TestDb.append_stream(@test_event, "test_stream-9", 1)
    end
  end
end
