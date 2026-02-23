defmodule FactTest do
  use ExUnit.Case

  alias Fact

  @moduletag :capture_log

  setup_all do
    Code.ensure_loaded!(Fact.EventDataIndexer)

    path = TestHelper.create_db("fact_test_")
    on_exit(fn -> TestHelper.rm_rf(path) end)
    {:ok, db} = Fact.open(path)

    {:ok, db: db}
  end

  test "module exists" do
    assert is_list(Fact.module_info())
  end

  test "append and read it back", %{db: db} do
    event = %{type: "egg_hatched"}

    assert {:ok, position} = Fact.append(db, event)

    record =
      Fact.read(db, :all, position: position - 1, count: 1)
      |> List.first()

    assert event.type == record["event_type"]
    assert position == record["store_position"]
  end

  test "append and read it back via a type query", %{db: db} do
    event = %{type: "pizza_ordered"}
    {:ok, position} = Fact.append(db, event)

    TestHelper.subscribe_and_wait(db, position)

    record =
      Fact.read(db, {:query, Fact.QueryItem.types("pizza_ordered")}, count: 1)
      |> List.first()

    assert event.type == record["event_type"]
    assert position == record["store_position"]
  end

  test "append and read it back via a tag query", %{db: db} do
    event = %{type: "egg_hatched", tags: ["egg:1"]}
    assert {:ok, position} = Fact.append(db, event)

    TestHelper.subscribe_and_wait(db, position)

    record =
      Fact.read(db, {:query, Fact.QueryItem.tags("egg:1")}, count: 1)
      |> List.first()

    assert event.type == record["event_type"]
    assert position == record["store_position"]
    assert "egg:1" in record["event_tags"]
  end

  test "append and read it back via a data query", %{db: db} do
    event = %{type: "egg_hatched", data: %{name: "Oogway"}}
    {:ok, position} = Fact.append(db, event)

    TestHelper.subscribe_and_wait(db, position)

    record =
      Fact.read(db, {:query, Fact.QueryItem.data(name: "Oogway")}, count: 1)
      |> List.first()

    assert event.type == record["event_type"]
    assert position == record["store_position"]
    assert event.data.name == record["event_data"]["name"]
  end

  test "append empty list of events is a no-op", %{db: db} do
    [last_event] = Fact.read(db, :all, direction: :backward, position: :end, count: 1)
    last_event_position = last_event["store_position"]
    assert {:ok, ^last_event_position} = Fact.append(db, [])
    all_events = Fact.read(db, :all)
  end

  test "append some events and read them back a variety of different ways", %{db: db} do
    events = [
      %{
        type: "turtle_mutated",
        data: %{turtle_id: 1, name: "Leonardo"},
        tags: ["tmnt", "blue"]
      },
      %{
        type: "turtle_mutated",
        data: %{turtle_id: 2, name: "Donatello"},
        tags: ["tmnt", "purple"]
      },
      %{
        type: "turtle_mutated",
        data: %{turtle_id: 3, name: "Raphael"},
        tags: ["tmnt", "red"]
      },
      %{
        type: "turtle_mutated",
        data: %{turtle_id: 4, name: "Michelangelo"},
        tags: ["tmnt", "orange"]
      },
      %{
        type: "lightsaber_constructed",
        data: %{saber_id: 1, constructed_by: "Darth Vader"},
        tags: ["imperial", "sith", "red"]
      },
      %{
        type: "lightsaber_constructed",
        data: %{saber_id: 2, constructed_by: "Anakin Skywalker"},
        tags: ["jedi", "blue"]
      },
      %{
        type: "lightsaber_acquired",
        data: %{saber_id: 2, wielded_by: "Luke Skywalker"},
        tags: ["rebel", "blue"]
      },
      %{
        type: "lightsaber_constructed",
        data: %{saber_id: 3, constructed_by: "Luke Skywalker"},
        tags: ["rebel", "jedi", "green"]
      },
      %{
        type: "lightsaber_constructed",
        data: %{saber_id: 4, constructed_by: "Ahsoka Tano"},
        tags: ["jedi", "green"]
      },
      %{
        type: "lightsaber_constructed",
        data: %{saber_id: 5, constructed_by: "Ahsoka Tano"},
        tags: ["jedi", "yellow"]
      },
      %{
        type: "lightsaber_constructed",
        data: %{saber_id: 6, constructed_by: "Ahsoka Tano"},
        tags: ["white"]
      },
      %{
        type: "lightsaber_constructed",
        data: %{saber_id: 7, constructed_by: "Ahsoka Tano"},
        tags: ["white"]
      },
      %{
        type: "lightsaber_constructed",
        data: %{saber_id: 8, constructed_by: "Mace Windu"},
        tags: ["jedi", "purple"]
      },
      %{
        type: "lightsaber_constructed",
        data: %{saber_id: 9, constructed_by: "Darth Maul"},
        tags: ["sith", "red"]
      },
      %{
        type: "lightsaber_constructed",
        data: %{saber_id: 10, constructed_by: "Tarre Vizsla"},
        tags: ["mandalorian", "jedi", "black"]
      },
      %{
        type: "lightsaber_acquired",
        data: %{saber_id: 10, wielded_by: "Pre Vizsla"},
        tags: ["mandalorian", "black"]
      },
      %{
        type: "lightsaber_acquired",
        data: %{saber_id: 10, wielded_by: "Darth Maul"},
        tags: ["sith", "black"]
      },
      %{
        type: "lightsaber_acquired",
        data: %{saber_id: 10, wielded_by: "Sabine Wren"},
        tags: ["rebel", "mandalorian", "black"]
      },
      %{
        type: "lightsaber_acquired",
        data: %{saber_id: 10, wielded_by: "Bo-Katan Kryze"},
        tags: ["mandalorian", "black"]
      },
      %{
        type: "lightsaber_acquired",
        data: %{saber_id: 10, wielded_by: "Moff Gideon"},
        tags: ["imperial", "black"]
      },
      %{
        type: "lightsaber_acquired",
        data: %{saber_id: 10, wielded_by: "Din Djarin"},
        tags: ["mandalorian", "black"]
      },
      %{
        type: "lightsaber_acquired",
        data: %{saber_id: 10, wielded_by: "Bo-Katan Kryze"},
        tags: ["mandalorian", "black"]
      }
    ]

    # Appending events with a variety of data points! 

    {:ok, end_position} = Fact.append(db, events)
    _start_position = end_position - length(events)

    TestHelper.subscribe_and_wait(db, end_position)

    # Let's have some fun querying these in different ways.

    # Read using the index directly
    tmnt_records_via_index = Fact.read(db, {:index, {Fact.EventTagsIndexer, nil}, "tmnt"})
    assert length(tmnt_records_via_index) == 4

    # Should be the same using a tag query
    tmnt_records_via_tag_query = Fact.read(db, {:query, Fact.QueryItem.tags("tmnt")})
    assert tmnt_records_via_index == tmnt_records_via_tag_query

    # Q: How many "red" events?
    # A: 3
    red_records = Fact.read(db, {:query, Fact.QueryItem.tags("red")})
    assert 3 == length(red_records)

    # Q: How many "red" "sith" events?
    # A: 2
    red_records = Fact.read(db, {:query, Fact.QueryItem.tags(["red", "sith"])})
    assert 2 == length(red_records)

    # Q: How many light sabers did Ahsoka contruct?
    # A: 4
    ahsoka_saber_query =
      Fact.QueryItem.types("lightsaber_constructed")
      |> Fact.QueryItem.data(constructed_by: "Ahsoka Tano")

    ahsoka_saber_records = Fact.read(db, {:query, ahsoka_saber_query})
    assert 4 == length(ahsoka_saber_records)

    # Q: ...AND how many of those were white?
    # A: 2
    ahsoka_white_saber_query =
      ahsoka_saber_query
      |> Fact.QueryItem.tags("white")

    ahsoka_white_saber_records = Fact.read(db, {:query, ahsoka_white_saber_query})
    assert 2 == length(ahsoka_white_saber_records)

    # Q: How many "purple" OR "jedi" events?
    # A: 7
    purple_or_jedi_query = [
      Fact.QueryItem.tags("purple"),
      Fact.QueryItem.tags("jedi")
    ]

    purple_or_jedi_events = Fact.read(db, {:query, purple_or_jedi_query})
    assert 7 == length(purple_or_jedi_events)

    # Let's just read the last 2 of the "purple" or "jedi" events...backwards
    last_2_purple_or_jedi_events_backwards =
      Fact.read(db, {:query, purple_or_jedi_query},
        direction: :backward,
        position: :end,
        count: 2
      )

    assert 2 == length(last_2_purple_or_jedi_events_backwards)
    assert Enum.at(last_2_purple_or_jedi_events_backwards, 0) == Enum.at(purple_or_jedi_events, 6)
    assert Enum.at(last_2_purple_or_jedi_events_backwards, 1) == Enum.at(purple_or_jedi_events, 5)
  end
end
