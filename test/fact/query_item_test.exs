defmodule Fact.QueryItemTest do
  use ExUnit.Case
  use Fact.EventKeys

  alias Fact.QueryItem

  @moduletag :capture_log

  doctest QueryItem

  setup_all do
    path = "query_item" <> Fact.Uuid.v4()
    instance = path |> String.to_atom()

    on_exit(fn -> File.rm_rf!(path) end)

    {:ok, _pid} = Fact.start_link(instance)

    events = [
      %{type: "CourseDefined", data: %{course_id: "c1"}, tags: ["course:c1"]},
      %{type: "CourseDefined", data: %{course_id: "c2"}, tags: ["course:c2"]},
      %{type: "CourseDefined", data: %{course_id: "c3"}, tags: ["course:c3"]},
      %{type: "StudentRegistered", data: %{student_id: "s1"}, tags: ["student:s1"]},
      %{type: "StudentRegistered", data: %{student_id: "s2"}, tags: ["student:s2"]},
      %{
        type: "StudentSubscribedToCourse",
        data: %{student_id: "s1", course_id: "c1"},
        tags: ["student:s1", "course:c1"]
      },
      %{
        type: "StudentSubscribedToCourse",
        data: %{student_id: "s1", course_id: "c3"},
        tags: ["student:s1", "course:c5"]
      },
      %{
        type: "StudentSubscribedToCourse",
        data: %{student_id: "s2", course_id: "c2"},
        tags: ["student:s2", "course:c2"]
      },
      %{
        type: "StudentSubscribedToCourse",
        data: %{student_id: "s2", course_id: "c1"},
        tags: ["student:s2", "course:c1"]
      },
      %{
        type: "StudentSubscribedToCourse",
        data: %{student_id: "s1", course_id: "c2"},
        tags: ["student:s1", "course:c2"]
      }
    ]

    Fact.append(instance, events)

    {:ok, instance: instance}
  end

  defp contains_events_at_store_positions(events, positions) do
    Enum.all?(positions, fn p -> Enum.any?(events, fn e -> e[@event_store_position] == p end) end)
  end

  describe "all/1" do
    test "combine with invalid query item" do
      assert_raise ArgumentError, fn -> QueryItem.all(:invalid) end
    end
  end

  describe "none/1" do
    test "combine with invalid query item" do
      assert_raise ArgumentError, fn -> QueryItem.none(:invalid) end
    end
  end

  describe "data/2" do
    test "combine with all, returns the query" do
      query_item =
        QueryItem.all()
        |> QueryItem.data(name: "Slim Shady")

      assert query_item == %Fact.QueryItem{data: [name: ["Slim Shady"]], tags: [], types: []}
    end

    test "combine with none, returns none" do
      query_item =
        QueryItem.none()
        |> QueryItem.data(name: "Slim Shady")

      assert query_item == :none
    end
  end

  describe "tags/2" do
    test "combine all with single tag, returns the query" do
      query_item =
        QueryItem.all()
        |> QueryItem.tags("tag1")

      assert query_item == %Fact.QueryItem{data: [], tags: ["tag1"], types: []}
    end

    test "combine all with multiple tags, returns none" do
      query_item =
        QueryItem.all()
        |> QueryItem.tags(["tag1", "tag2"])

      assert query_item == %Fact.QueryItem{data: [], tags: ["tag1", "tag2"], types: []}
    end

    test "combine none with single tag, returns none" do
      query_item =
        QueryItem.none()
        |> QueryItem.tags("tag1")

      assert query_item == :none
    end

    test "combine none with multiple tags, returns none" do
      query_item =
        QueryItem.none()
        |> QueryItem.tags(["tag1", "tag2"])

      assert query_item == :none
    end
  end

  describe "types/2" do
    test "combine all with single type, returns the query" do
      query_item =
        QueryItem.all()
        |> QueryItem.types("type1")

      assert query_item == %Fact.QueryItem{data: [], tags: [], types: ["type1"]}
    end

    test "combine all with multiple tags, returns none" do
      query_item =
        QueryItem.all()
        |> QueryItem.types(["type1", "type2"])

      assert query_item == %Fact.QueryItem{data: [], tags: [], types: ["type1", "type2"]}
    end

    test "combine none with single type, returns none" do
      query_item =
        QueryItem.none()
        |> QueryItem.types("type1")

      assert query_item == :none
    end

    test "combine none with multiple types, returns none" do
      query_item =
        QueryItem.none()
        |> QueryItem.types(["type1", "type2"])

      assert query_item == :none
    end
  end

  describe "hash/1" do
    test "should produce sha1 hash of :all" do
      hash = QueryItem.all() |> QueryItem.hash()
      assert is_binary(hash)
      assert 40 == String.length(hash)
    end

    test "should produce sha1 hash of :none" do
      hash = QueryItem.none() |> QueryItem.hash()
      assert is_binary(hash)
      assert 40 == String.length(hash)
    end

    test "should produce sha1 hash of single query item" do
      hash = QueryItem.tags("tag1") |> QueryItem.hash()
      assert is_binary(hash)
      assert 40 == String.length(hash)
    end

    test "should produce sha1 hash of query item list" do
      hash =
        QueryItem.join([QueryItem.tags("tag1"), QueryItem.types("type1")]) |> QueryItem.hash()

      assert is_binary(hash)
      assert 40 == String.length(hash)
    end

    test "should fail when hash invalid query item" do
      assert_raise ArgumentError, fn ->
        QueryItem.hash(:invalid_query_item)
      end
    end
  end

  describe "query function execution" do
    test "query by none", %{instance: db} do
      events = Fact.read(db, QueryItem.none()) |> Enum.to_list()
      assert 0 == length(events)
    end

    test "query by none function", %{instance: db} do
      fun = QueryItem.none() |> QueryItem.to_function()
      events = Fact.read(db, fun) |> Enum.to_list()
      assert 0 == length(events)
    end

    test "query by all", %{instance: db} do
      events = Fact.read(db, QueryItem.all()) |> Enum.to_list()
      assert 10 == length(events)
    end

    test "query by empty join, returns all events", %{instance: db} do
      events = Fact.read(db, QueryItem.join([])) |> Enum.to_list()
      assert 10 == length(events)
    end

    test "query by all function", %{instance: db} do
      fun = QueryItem.all() |> QueryItem.to_function()
      events = Fact.read(db, fun) |> Enum.to_list()
      assert 10 == length(events)
    end

    test "query by single type", %{instance: db} do
      events = Fact.read(db, QueryItem.types("StudentSubscribedToCourse")) |> Enum.to_list()
      assert 5 == length(events)
      assert contains_events_at_store_positions(events, [6, 7, 8, 9, 10])
    end

    test "query by multiple types", %{instance: db} do
      events =
        Fact.read(db, QueryItem.types(["StudentRegistered", "StudentSubscribedToCourse"]))
        |> Enum.to_list()

      assert 7 == length(events)
      assert contains_events_at_store_positions(events, [4, 5, 6, 7, 8, 9, 10])
    end

    test "query by single tag", %{instance: db} do
      events = Fact.read(db, QueryItem.tags("student:s1")) |> Enum.to_list()
      assert 4 == length(events)
      assert contains_events_at_store_positions(events, [4, 6, 7, 10])
    end

    test "query by multiple tags", %{instance: db} do
      events = Fact.read(db, QueryItem.tags(["student:s1", "course:c2"])) |> Enum.to_list()
      assert 1 == length(events)
      assert contains_events_at_store_positions(events, [10])
    end

    test "query by single data property", %{instance: db} do
      events = Fact.read(db, QueryItem.data(course_id: "c1")) |> Enum.to_list()
      assert 3 == length(events)
      assert contains_events_at_store_positions(events, [1, 6, 9])
    end

    test "query by multiple data properties", %{instance: db} do
      events = Fact.read(db, QueryItem.data(course_id: "c1", student_id: "s2")) |> Enum.to_list()
      assert 1 == length(events)
      assert contains_events_at_store_positions(events, [9])
    end

    test "query by single data property with multiple values", %{instance: db} do
      events = Fact.read(db, QueryItem.data(course_id: "c1", course_id: "c2")) |> Enum.to_list()
      assert 6 == length(events)
      assert contains_events_at_store_positions(events, [1, 2, 6, 8, 9, 10])
    end
  end
end
