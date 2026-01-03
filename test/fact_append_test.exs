#defmodule Fact.AppendTest do
#  use ExUnit.Case, async: false
#
#  alias Fact
#  alias Fact.TestHelper
#
#  @moduletag capture_log: true
#
#  setup_all do
#    path = TestHelper.create("append", :all_indexers)
#    on_exit(fn -> TestHelper.rm_rf(path) end)
#    {:ok, instance} = Fact.open(path)
#    {:ok, instance: instance}
#  end
#
#  describe "Fact.append/*" do
#    test "should fail when events are not a list", %{instance: db} do
#      assert {:error, :invalid_event_list} == Fact.append(db, nil)
#    end
#
#    test "should fail when events are not a list of maps", %{instance: db} do
#      assert {:error, :invalid_events} == Fact.append(db, [1, 2, 3])
#    end
#
#    test "should fail when fail_if_match is not a function", %{instance: db} do
#      assert {:error, :invalid_fail_if_match_query} ==
#               Fact.append(db, %{type: "TestEvent"}, :not_a_function)
#    end
#
#    test "should fail when fail_if_match has wrong arity", %{instance: db} do
#      assert {:error, :invalid_fail_if_match_query} ==
#               Fact.append(db, %{type: "TestEvent"}, fn x, y -> x + y end)
#    end
#
#    test "should fail when after_position is not an integer", %{instance: db} do
#      assert {:error, :invalid_after_position} ==
#               Fact.append(db, %{type: "TestEvent"}, Fact.Query.from_none(), "0")
#    end
#
#    test "should fail when after_position is negative", %{instance: db} do
#      assert {:error, :invalid_after_position} ==
#               Fact.append(db, %{type: "TestEvent"}, Fact.Query.from_none(), -1)
#    end
#
#    test "should append an event with no conditions", %{instance: db} do
#      assert {:ok, _} = Fact.append(db, %{type: "TestEvent"})
#    end
#
#    test "should append an event with a fail_if_match query and no after position", %{
#      instance: db
#    } do
#      {:ok, query} = Fact.Query.from_tags("test:t1")
#      assert {:ok, _} = Fact.append(db, %{type: "TestEvent", tags: ["test:t1"]}, query)
#    end
#
#    test "should append an event with a fail_if_match query and after position", %{instance: db} do
#      {:ok, query} = Fact.Query.from_tags("test:t2")
#      assert {:ok, _} = Fact.append(db, %{type: "TestEvent", tags: ["test:t2"]}, query, 1)
#    end
#
#    test "should fail when fail_if_match query contains events", %{instance: db} do
#      {:ok, query} = Fact.Query.from_tags("test:t3")
#      {:ok, position} = Fact.append(db, %{type: "TestEvent", tags: ["test:t3"]}, query)
#
#      assert {:error, %Fact.ConcurrencyError{source: :all, expected: 0, actual: position}} ==
#               Fact.append(db, %{type: "TestEvent", tags: ["test:t3"]}, query)
#    end
#
#    test "should fail when fail_if_match query contains events after position", %{instance: db} do
#      {:ok, query} = Fact.Query.from_tags("test:t4")
#      {:ok, position} = Fact.append(db, %{type: "TestEvent", tags: ["test:t4"]}, query)
#      expectation = position - 1
#
#      assert {:error,
#              %Fact.ConcurrencyError{source: :all, expected: expectation, actual: position}} ==
#               Fact.append(db, %{type: "TestEvent", tags: ["test:t4"]}, query, expectation)
#    end
#
#    test "should append an event when fail_if_match query contains no events after position", %{
#      instance: db
#    } do
#      {:ok, query} = Fact.Query.from_tags("test:t5")
#      {:ok, position} = Fact.append(db, %{type: "TestEvent", tags: ["test:t5"]}, query)
#      assert {:ok, _} = Fact.append(db, %{type: "TestEvent", tags: ["test:t5"]}, query, position)
#    end
#  end
#
#  @test_event %{type: "TestEvent"}
#
#  describe "Fact.append_stream/*" do
#    test "should fail when events are not a list", %{instance: db} do
#      assert {:error, :invalid_event_list} == Fact.append_stream(db, nil, "TestStream")
#    end
#
#    test "should fail when events are not a list of maps", %{instance: db} do
#      assert {:error, :invalid_events} == Fact.append_stream(db, [1, 2, 3], "TestStream")
#    end
#
#    test "should fail when event stream is not a string", %{instance: db} do
#      assert {:error, :invalid_event_stream} ==
#               Fact.append_stream(db, @test_event, :not_valid_stream)
#    end
#
#    test "should fail when expected position is not valid atom", %{instance: db} do
#      assert {:error, :invalid_expected_position} ==
#               Fact.append_stream(db, @test_event, "TestStream", :invalid)
#    end
#
#    test "should fail when expected position is not an integer", %{instance: db} do
#      assert {:error, :invalid_expected_position} ==
#               Fact.append_stream(db, @test_event, "TestStream", 1.2)
#    end
#
#    test "should append event to stream given no expected position", %{instance: db} do
#      assert {:ok, 1} == Fact.append_stream(db, @test_event, "test_stream-1")
#    end
#
#    test "should append event to stream given :any expected position", %{instance: db} do
#      assert {:ok, 1} == Fact.append_stream(db, @test_event, "test_stream-2", :any)
#    end
#
#    test "should append event to existing stream given :any expected", %{instance: db} do
#      Fact.append_stream(db, @test_event, "test_stream-2b", :any)
#      assert {:ok, 2} == Fact.append_stream(db, @test_event, "test_stream-2b", :any)
#    end
#
#    test "should append event to new stream given :none expected", %{instance: db} do
#      assert {:ok, 1} == Fact.append_stream(db, @test_event, "test_stream-3", :none)
#    end
#
#    test "should fail to append event given stream exists and :none expected", %{instance: db} do
#      assert {:ok, 1} == Fact.append_stream(db, @test_event, "test_stream-4", :none)
#
#      assert {:error, %Fact.ConcurrencyError{source: "test_stream-4", expected: :none, actual: 1}} ==
#               Fact.append_stream(db, @test_event, "test_stream-4", :none)
#    end
#
#    test "should fail to append event to new stream given :exists expected", %{instance: db} do
#      assert {:error,
#              %Fact.ConcurrencyError{source: "test_stream-5", expected: :exists, actual: 0}} ==
#               Fact.append_stream(db, @test_event, "test_stream-5", :exists)
#    end
#
#    test "should append event to existing stream given :exists expected", %{instance: db} do
#      Fact.append_stream(db, @test_event, "test_stream-6")
#      assert {:ok, 2} == Fact.append_stream(db, @test_event, "test_stream-6", :exists)
#    end
#
#    test "should append event to new stream given 0 as expected position", %{instance: db} do
#      assert {:ok, 1} == Fact.append_stream(db, @test_event, "test_stream-7", 0)
#    end
#
#    test "should append event to new stream given last as expected position", %{instance: db} do
#      {:ok, position} =
#        Fact.append_stream(db, [@test_event, @test_event, @test_event], "test_stream-8", 0)
#
#      assert {:ok, 4} == Fact.append_stream(db, @test_event, "test_stream-8", position)
#    end
#
#    test "should fail to append event when given expected position before actual position", %{
#      instance: db
#    } do
#      {:ok, position} =
#        Fact.append_stream(db, [@test_event, @test_event, @test_event], "test_stream-9", 0)
#
#      assert {:error,
#              %Fact.ConcurrencyError{source: "test_stream-9", expected: 1, actual: position}} ==
#               Fact.append_stream(db, @test_event, "test_stream-9", 1)
#    end
#  end
#end
