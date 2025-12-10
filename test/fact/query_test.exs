defmodule Fact.QueryTest do
  use ExUnit.Case
  use Fact.EventKeys

  alias Fact.Query

  @moduletag :capture_log

  setup_all do
    path = "test_" <> (DateTime.utc_now() |> DateTime.to_unix() |> to_string())
    instance = path |> String.to_atom()

    on_exit(fn -> File.rm_rf!(path) end)

    {:ok, _pid} = Fact.start_link(instance)

    Fact.append(instance, [
      %{
        type: "CourseDefined",
        data: %{
          course_id: "c1",
          department_id: "d1",
          course_subject_code: "CST",
          course_number: 116,
          capacity: 30,
          course_title: "C++ Programming I"
        },
        tags: ["course:c1", "department:d1"]
      },
      %{
        type: "CourseDefined",
        data: %{
          course_id: "c2",
          department_id: "d1",
          course_subject_code: "CST",
          course_number: 126,
          capacity: 25,
          course_title: "C++ Programming II"
        },
        tags: ["course:c2", "department:d1"]
      },
      %{
        type: "StudentRegistered",
        data: %{student_id: "s1", first_name: "John", last_name: "Blutarsky"},
        tags: ["student:s1"]
      },
      %{
        type: "CourseDefined",
        data: %{
          course_id: "c3",
          department_id: "d2",
          course_subject_code: "MATH",
          course_number: 251,
          capacity: 80,
          course_title: "Differential Calculus"
        },
        tags: ["course:c3", "department:d2"]
      },
      %{
        type: "StudentRegistered",
        data: %{student_id: "s2", first_name: "Frank", last_name: "Ricard"},
        tags: ["student:s2"]
      },
      %{
        type: "StudentSubscribedToCourse",
        data: %{course_id: "c1", student_id: "s1"},
        tags: ["course:c1", "student:s1"]
      },
      %{
        type: "StudentSubscribedToCourse",
        data: %{course_id: "c1", student_id: "s1"},
        tags: ["course:c1", "student:s2"]
      }
    ])

    {:ok, instance: instance}
  end

  defp contains_events_at_store_positions(events, positions) do
    Enum.all?(positions, fn p -> Enum.any?(events, fn e -> e[@event_store_position] == p end) end)
  end

  describe "Fact.Query.from_types/1" do
    test "should fail given nil" do
      assert {:error, :invalid_type_criteria} == Query.from_types(nil)
    end

    test "should fail given empty list" do
      assert {:error, :empty_type_list} == Query.from_types([])
    end

    test "should return query function given valid type" do
      assert {:ok, fun} = Query.from_types("StudentRegistered")
      assert is_function(fun)
    end

    test "should return correct result set", %{instance: db} do
      {:ok, fun} = Query.from_types("StudentSubscribedToCourse")
      events = Fact.read(db, fun) |> Enum.to_list()
      assert length(events) == 2
      assert contains_events_at_store_positions(events, [6, 7])
    end

    test "should return correct result set for multiple types", %{instance: db} do
      {:ok, fun} = Query.from_types(["StudentRegistered", "StudentSubscribedToCourse"])
      events = Fact.read(db, fun) |> Enum.to_list()
      assert length(events) == 4
      assert contains_events_at_store_positions(events, [3, 5, 6, 7])
    end
  end

  describe "Fact.Query.from_types!/1" do
    test "should fail given nil" do
      assert_raise ArgumentError, fn -> Query.from_types!(nil) end
    end

    test "should fail given empty list" do
      assert_raise ArgumentError, fn -> Query.from_types!([]) end
    end

    test "should return query function given valid type" do
      assert fun = Query.from_types!("StudentRegistered")
      assert is_function(fun)
    end

    test "should return correct result set", %{instance: db} do
      fun = Query.from_types!("StudentSubscribedToCourse")
      events = Fact.read(db, fun) |> Enum.to_list()
      assert length(events) == 2
      assert contains_events_at_store_positions(events, [6, 7])
    end

    test "should return correct result set for multiple types", %{instance: db} do
      fun = Query.from_types!(["StudentRegistered", "StudentSubscribedToCourse"])
      events = Fact.read(db, fun) |> Enum.to_list()
      assert length(events) == 4
      assert contains_events_at_store_positions(events, [3, 5, 6, 7])
    end
  end

  describe "Fact.Query.from_tags/1" do
    test "should fail given nil" do
      assert {:error, :invalid_tag_criteria} == Query.from_tags(nil)
    end

    test "should fail given non-string" do
      assert {:error, :invalid_tag_criteria} == Query.from_tags(:tagged)
    end

    test "should fail given empty list" do
      assert {:error, :empty_tag_list} == Query.from_tags([])
    end

    test "should return query function given valid tag" do
      assert {:ok, fun} = Query.from_tags("student:s1")
      assert is_function(fun)
    end

    test "should return correct result set", %{instance: db} do
      {:ok, fun} = Query.from_tags("student:s1")
      events = Fact.read(db, fun) |> Enum.to_list()
      assert length(events) == 2
      assert contains_events_at_store_positions(events, [3, 6])
    end

    test "should return correct result set for multiple tags", %{instance: db} do
      {:ok, fun} = Query.from_tags(["student:s2", "course:c1"])
      events = Fact.read(db, fun) |> Enum.to_list()
      assert length(events) == 1
      assert contains_events_at_store_positions(events, [7])
    end
  end

  describe "Fact.Query.from_tags!/1" do
    test "should fail given nil" do
      assert_raise ArgumentError, fn -> Query.from_tags!(nil) end
    end

    test "should fail given non-string" do
      assert_raise ArgumentError, fn -> Query.from_tags!(:tagged) end
    end

    test "should fail given empty list" do
      assert_raise ArgumentError, fn -> Query.from_tags!([]) end
    end

    test "should return query function given valid tag" do
      assert fun = Query.from_tags!("student:s1")
      assert is_function(fun)
    end

    test "should return correct result set", %{instance: db} do
      fun = Query.from_tags!("student:s1")
      events = Fact.read(db, fun) |> Enum.to_list()
      assert length(events) == 2
      assert contains_events_at_store_positions(events, [3, 6])
    end

    test "should return correct result set for multiple tags", %{instance: db} do
      fun = Query.from_tags!(["student:s2", "course:c1"])
      events = Fact.read(db, fun) |> Enum.to_list()
      assert length(events) == 1
      assert contains_events_at_store_positions(events, [7])
    end
  end

  describe "Fact.Query.from_data/1" do
    test "should fail given nil" do
      assert {:error, :invalid_data_criteria} == Query.from_data(nil)
    end

    test "should fail given empty keyword list" do
      assert {:error, :empty_data_list} = Query.from_data([])
    end

    test "should return query function given valid keyword list" do
      assert {:ok, fun} = Query.from_data(student_id: "s1")
      assert is_function(fun)
    end

    test "should return query function given valid list of tuples" do
      assert {:ok, fun} = Query.from_data([{"student_id", "s1"}])
      assert is_function(fun)
    end

    test "should return correct result set", %{instance: db} do
      {:ok, fun} = Query.from_data(course_subject_code: "CST")
      events = Fact.read(db, fun) |> Enum.to_list()
      assert length(events) == 2
      assert contains_events_at_store_positions(events, [1, 2])
    end

    test "should return correct result set for multiple matching keys", %{instance: db} do
      {:ok, fun} = Query.from_data(course_subject_code: "CST", course_subject_code: "MATH")
      events = Fact.read(db, fun) |> Enum.to_list()
      assert length(events) == 3
      assert contains_events_at_store_positions(events, [1, 2, 4])
    end

    test "should return no events when no data properties match", %{instance: db} do
      {:ok, fun} = Query.from_data(course_subject_code: "LIT")
      events = Fact.read(db, fun) |> Enum.to_list()
      assert length(events) == 0
    end

    test "should return correct result set for multiple different keys", %{instance: db} do
      {:ok, fun} = Query.from_data(course_subject_code: "CST", course_number: 126)
      events = Fact.read(db, fun) |> Enum.to_list()
      assert length(events) == 1
      assert contains_events_at_store_positions(events, [2])
    end
  end

  describe "Fact.Query.from_data!/1" do
    test "should fail given nil" do
      assert_raise ArgumentError, fn -> Query.from_data!(nil) end
    end

    test "should fail given empty keyword list" do
      assert_raise ArgumentError, fn -> Query.from_data!([]) end
    end

    test "should return query function given valid keyword list" do
      assert fun = Query.from_data!(student_id: "s1")
      assert is_function(fun)
    end

    test "should return query function given valid list of tuples" do
      assert fun = Query.from_data!([{"student_id", "s1"}])
      assert is_function(fun)
    end
  end

  describe "Fact.Query.from_all/0" do
    test "`should return a query function" do
      assert fun = Query.from_all()
      assert is_function(fun)
    end

    test "should return all events", %{instance: db} do
      fun = Query.from_all()
      events = Fact.read(db, fun) |> Enum.to_list()
      assert contains_events_at_store_positions(events, 1..7 |> Enum.to_list())
    end
  end

  describe "Fact.Query.from_none/0" do
    test "should return a query function" do
      assert fun = Query.from_none()
      assert is_function(fun)
    end

    test "should return no events", %{instance: db} do
      fun = Query.from_none()
      events = Fact.read(db, fun) |> Enum.to_list()
      assert length(events) == 0
    end
  end

  describe "Fact.Query.from/3" do
    test "should fail given no arguments" do
      assert {:error, :no_criteria} == Fact.Query.from()
    end

    test "should fail given all nil criteria" do
      assert {:error, :no_criteria} == Fact.Query.from(nil, nil, nil)
    end

    test "should return correct result set for single event type", %{instance: db} do
      {:ok, fun} = Fact.Query.from("StudentSubscribedToCourse")
      events = Fact.read(db, fun) |> Enum.to_list()
      assert length(events) == 2
      assert contains_events_at_store_positions(events, [6, 7])
    end

    test "should return correct result set for single event tag", %{instance: db} do
      {:ok, fun} = Fact.Query.from([], ["student:s1"], [])
      events = Fact.read(db, fun) |> Enum.to_list()
      assert length(events) == 2
      assert contains_events_at_store_positions(events, [3, 6])
    end

    test "should return correct result set for single data criteria", %{instance: db} do
      {:ok, fun} = Fact.Query.from([], [], course_subject_code: "CST")
      events = Fact.read(db, fun) |> Enum.to_list()
      assert length(events) == 2
      assert contains_events_at_store_positions(events, [1, 2])
    end
    
    test "should return correct result set for event type and tag criteria", %{instance: db} do
      {:ok, fun} = Fact.Query.from("StudentSubscribedToCourse", "student:s1", [])
      events = Fact.read(db, fun) |> Enum.to_list()
      assert length(events) == 1
      assert contains_events_at_store_positions(events, [6])
    end
    
    test "should return correct result set for event type and data criteria", %{instance: db} do
      {:ok, fun} = Fact.Query.from("CourseDefined", [], course_subject_code: "MATH")
      events = Fact.read(db, fun) |> Enum.to_list()
      assert length(events) == 1
      assert contains_events_at_store_positions(events, [4])
    end

    test "should return correct result set for event tag and data criteria", %{instance: db} do
      {:ok, fun} = Fact.Query.from([], ["course:c1"], course_subject_code: "CST")
      events = Fact.read(db, fun) |> Enum.to_list()
      assert length(events) == 1
      assert contains_events_at_store_positions(events, [1])
    end
    
    test "should return correct result set for event type, tag, and data criteria", %{instance: db} do
      {:ok, fun} = Fact.Query.from(["CourseDefined"], ["department:d1"], course_number: 126)
      events = Fact.read(db, fun) |> Enum.to_list()
      assert length(events) == 1
      assert contains_events_at_store_positions(events, [2])
    end
  end
  
  describe "Fact.Query.combine/2" do
    test "should fail given bad op" do
      assert {:error, :invalid_op} == Fact.Query.combine(:xor, [Fact.Query.from_all(), Fact.Query.from_none()])
    end
    
    test "should fail given no queries" do
      assert {:error, :empty_query_list} == Fact.Query.combine(:and, [])
    end
    
    test "should fail given invalid query" do
      assert {:error, :non_function_query} == Fact.Query.combine(:and, ["not a query", Fact.Query.from_all()])
    end

    test "should be no op given :and op and single query" do
      fun = Fact.Query.from_all()
      assert {:ok, fun} == Fact.Query.combine(:and, [fun])
    end
    
    test "should return correct result set for combine with :or", %{instance: db} do
      {:ok, query1} = Fact.Query.from_tags("course:c1")
      {:ok, query2} = Fact.Query.from_data(course_subject_code: "MATH")
      {:ok, combined} = Fact.Query.combine(:or, [query1, query2])
      events = Fact.read(db, combined) |> Enum.to_list()
      assert length(events) == 4
      assert contains_events_at_store_positions(events, [1,4,6,7])
    end
  end
  
  describe "Fact.Query.combine!/2" do
    test "should fail given bad op" do
      assert_raise ArgumentError, fn ->
        Fact.Query.combine!(:xor, [Fact.Query.from_all(), Fact.Query.from_none()])
      end 
    end

    test "should fail given no queries" do
      assert_raise ArgumentError, fn -> 
        Fact.Query.combine!(:and, [])
      end
    end

    test "should fail given invalid query" do
      assert_raise ArgumentError, fn ->
        Fact.Query.combine!(:and, ["not a query", Fact.Query.from_all()])
      end
    end

    test "should return correct result set for combine with :or", %{instance: db} do
      {:ok, query1} = Fact.Query.from_tags("course:c1")
      {:ok, query2} = Fact.Query.from_data(course_subject_code: "MATH")
      combined = Fact.Query.combine!(:or, [query1, query2])
      events = Fact.read(db, combined) |> Enum.to_list()
      assert length(events) == 4
      assert contains_events_at_store_positions(events, [1,4,6,7])
    end
  end
end
