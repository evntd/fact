defmodule Fact.ReadTest do
  use ExUnit.Case, async: true
  use Fact.Types

  alias Fact.TestHelper

  @moduletag :capture_log

  setup_all do
    path = TestHelper.create("read", :all_indexers)
    on_exit(fn -> TestHelper.rm_rf(path) end)

    {:ok, instance} = Fact.open(path)

    non_stream_events = [
      %{type: "CourseDefined", data: %{course_id: "c1"}, tags: ["course:c1"]},
      %{type: "CourseDefined", data: %{course_id: "c2"}, tags: ["course:c2"]},
      %{type: "CourseDefined", data: %{course_id: "c3"}, tags: ["course:c3"]},
      %{type: "CourseDefined", data: %{course_id: "c4"}, tags: ["course:c4"]},
      %{type: "CourseDefined", data: %{course_id: "c5"}, tags: ["course:c5"]}
    ]

    stream_events = [
      %{
        type: "StudentSubscribedToCourse",
        data: %{student_id: "s1", course_id: "c1"},
        tags: ["student:s1", "course:c1"]
      },
      %{
        type: "StudentSubscribedToCourse",
        data: %{student_id: "s1", course_id: "c2"},
        tags: ["student:s1", "course:c2"]
      },
      %{
        type: "StudentSubscribedToCourse",
        data: %{student_id: "s1", course_id: "c3"},
        tags: ["student:s1", "course:c3"]
      },
      %{
        type: "StudentSubscribedToCourse",
        data: %{student_id: "s1", course_id: "c4"},
        tags: ["student:s1", "course:c4"]
      },
      %{
        type: "StudentSubscribedToCourse",
        data: %{student_id: "s1", course_id: "c5"},
        tags: ["student:s1", "course:c5"]
      }
    ]

    events = non_stream_events ++ stream_events

    TestHelper.subscribe_to_indexing(instance)

    Fact.append(instance, non_stream_events)
    Fact.append_stream(instance, stream_events, "student-s1")

    TestHelper.wait_for_event_position_to_be_indexed(length(events), __MODULE__)

    {:ok, instance: instance}
  end

  describe "Fact.read/3 - :all" do
    test "read all, should return all events in the order written", %{instance: db} do
      events = Fact.read(db, :all) |> Enum.to_list()
      assert 10 == length(events)

      first_event = Enum.at(events, 0)
      assert 1 == first_event[@event_store_position]

      last_event = Enum.at(events, -1)
      assert 10 == last_event[@event_store_position]
    end

    test "read all backwards from end, should returns all events in reverse order", %{
      instance: db
    } do
      events = Fact.read(db, :all, direction: :backward, position: :end) |> Enum.to_list()
      assert 10 == length(events)

      first_event = Enum.at(events, 0)
      assert 10 == first_event[@event_store_position]

      last_event = Enum.at(events, -1)
      assert 1 == last_event[@event_store_position]
    end

    test "read all backwards from start, should return no events", %{instance: db} do
      events = Fact.read(db, :all, direction: :backward, position: :start) |> Enum.to_list()
      assert 0 == length(events)
    end

    test "read all from position, should return all events after the position", %{instance: db} do
      events = Fact.read(db, :all, position: 4) |> Enum.to_list()
      assert 6 == length(events)

      first_event = Enum.at(events, 0)
      assert 5 == first_event[@event_store_position]

      last_event = Enum.at(events, -1)
      assert 10 == last_event[@event_store_position]
    end

    test "read all backwards from position, should return all events at and before the position",
         %{
           instance: db
         } do
      events = Fact.read(db, :all, direction: :backward, position: 4) |> Enum.to_list()
      assert 4 == length(events)

      first_event = Enum.at(events, 0)
      assert 4 == first_event[@event_store_position]

      last_event = Enum.at(events, -1)
      assert 1 == last_event[@event_store_position]
    end

    test "read all backwards from the end, should return all events in reverse order", %{
      instance: db
    } do
      events = Fact.read(db, :all, direction: :backward, position: :end) |> Enum.to_list()
      assert 10 == length(events)

      first_event = Enum.at(events, 0)
      assert 10 == first_event[@event_store_position]

      last_event = Enum.at(events, -1)
      assert 1 == last_event[@event_store_position]
    end

    test "read all forward from end, should return no events", %{instance: db} do
      events = Fact.read(db, :all, direction: :forward, position: :end) |> Enum.to_list()
      assert 0 == length(events)
    end

    test "read all with a count, should return that number of events from the start", %{
      instance: db
    } do
      events = Fact.read(db, :all, count: 7) |> Enum.to_list()
      assert 7 == length(events)

      first_event = Enum.at(events, 0)
      assert 1 == first_event[@event_store_position]

      last_event = Enum.at(events, -1)
      assert 7 == last_event[@event_store_position]
    end
  end

  describe "Fact.read/3" do
    test "should fail when given invalid read direction", %{instance: db} do
      assert_raise Fact.DatabaseError, "invalid read direction: invalid", fn ->
        Fact.read(db, :all, direction: :invalid)
      end
    end

    test "should fail when given negative start position", %{instance: db} do
      assert_raise Fact.DatabaseError, "invalid read position: -1", fn ->
        Fact.read(db, :all, position: -1)
      end
    end

    test "should fail when given negative count", %{instance: db} do
      assert_raise Fact.DatabaseError, "invalid read count: -1", fn ->
        Fact.read(db, :all, count: -1)
      end
    end

    test "should read all events from a stream", %{instance: db} do
      events = Fact.read(db, {:stream, "student-s1"}) |> Enum.to_list()
      assert 5 == length(events)

      first_event = Enum.at(events, 0)
      assert 6 == first_event[@event_store_position]
      assert 1 == first_event[@event_stream_position]

      last_event = Enum.at(events, -1)
      assert 10 == last_event[@event_store_position]
      assert 5 == last_event[@event_stream_position]
    end

    test "should read all events from a stream backwards", %{instance: db} do
      events = Fact.read(db, {:stream, "student-s1"}, direction: :backward) |> Enum.to_list()
      assert 0 == length(events)
    end

    test "should read stream events backward starting at the end", %{instance: db} do
      events =
        Fact.read(db, {:stream, "student-s1"}, direction: :backward, position: :end)
        |> Enum.to_list()

      assert 5 == length(events)

      first_event = Enum.at(events, 0)
      assert 10 == first_event[@event_store_position]

      last_event = Enum.at(events, -1)
      assert 6 == last_event[@event_store_position]
    end

    test "should read stream events forward starting at the end", %{instance: db} do
      events =
        Fact.read(db, {:stream, "student-s1"}, direction: :forward, position: :end)
        |> Enum.to_list()

      assert 0 == length(events)
    end
  end
end
