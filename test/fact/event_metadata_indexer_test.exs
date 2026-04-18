defmodule Fact.EventMetadataIndexerTest do
  @moduledoc false

  use ExUnit.Case

  alias Fact.EventMetadataIndexer

  setup_all do
    seam = Fact.Seam.EventSchema.Standard.V1.init()
    schema = Fact.Seam.EventSchema.Standard.V1.get(seam, [])

    {:ok, schema: schema}
  end

  test "indexes the specified indexer_key for event metadata with string key", %{schema: schema} do
    event = %{
      schema.event_type => "OrderPlaced",
      schema.event_data => %{"order_id" => "ord_1"},
      schema.event_metadata => %{"correlation_id" => "abc-123", "causation_id" => "def-456"}
    }

    assert "abc-123" =
             EventMetadataIndexer.index_event(schema, event, indexer_key: "correlation_id")

    assert "def-456" ==
             EventMetadataIndexer.index_event(schema, event, indexer_key: "causation_id")
  end

  test "indexes the specified indexer_key for event metadata with atom key", %{schema: schema} do
    event = %{
      schema.event_type => "OrderPlaced",
      schema.event_data => %{"order_id" => "ord_1"},
      schema.event_metadata => %{correlation_id: "abc-123", causation_id: "def-456"}
    }

    assert "abc-123" =
             EventMetadataIndexer.index_event(schema, event, indexer_key: "correlation_id")

    assert "def-456" ==
             EventMetadataIndexer.index_event(schema, event, indexer_key: "causation_id")
  end

  test "does not index event when event metadata does not define the key", %{schema: schema} do
    event = %{
      schema.event_type => "OrderPlaced",
      schema.event_data => %{"order_id" => "ord_1"},
      schema.event_metadata => %{"correlation_id" => "abc-123"}
    }

    assert nil === EventMetadataIndexer.index_event(schema, event, indexer_key: "tenant_id")
  end
end
