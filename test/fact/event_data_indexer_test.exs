defmodule Fact.EventDataIndexerTest do
  @moduledoc false

  use ExUnit.Case

  alias Fact.EventDataIndexer

  setup_all do
    seam = Fact.Seam.EventSchema.Standard.V1.init()
    schema = Fact.Seam.EventSchema.Standard.V1.get(seam, [])

    {:ok, schema: schema}
  end

  test "indexes the specified indexer_key for event data with string key", %{schema: schema} do
    # "Bandit" was my dog from 1st to 8th grade, but I never that for any password recovery answer
    event = %{
      schema.event_type => "PetAdopted",
      schema.event_data => %{"name" => "Bandit", "breed" => "Lab/Dalmatian"}
    }

    assert "Bandit" = EventDataIndexer.index_event(schema, event, indexer_key: "name")
    assert "Lab/Dalmatian" == EventDataIndexer.index_event(schema, event, indexer_key: "breed")
  end

  test "indexes the specified indexer_key for event data with atom key", %{schema: schema} do
    # "Snicker" was my dog from 9th grade through college, and stayed living with my Grandma 
    # until she passed...Snicker, not Grandma.
    event = %{
      schema.event_type => "PetAdopted",
      schema.event_data => %{name: "Snicker", breed: "???"}
    }

    assert "Snicker" = EventDataIndexer.index_event(schema, event, indexer_key: "name")
    assert "???" == EventDataIndexer.index_event(schema, event, indexer_key: "breed")
  end

  test "does not index event when event data does not define the key", %{schema: schema} do
    # "Pinkerton" was the dog my wife I got when we were newly married. Also my favorize Weezer album.
    event = %{
      schema.event_type => "PetAdopted",
      schema.event_data => %{"name" => "Pinkerton", "breed" => "Pug"}
    }

    index_opts = [indexer_key: "age"]
    assert nil === EventDataIndexer.index_event(schema, event, index_opts)
  end
end
