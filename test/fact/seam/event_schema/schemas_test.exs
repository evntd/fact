defmodule Fact.Seam.EventSchema.SchemasTest do
  use ExUnit.Case, async: true

  describe "Emmett.V1" do
    alias Fact.Seam.EventSchema.Emmett.V1

    test "get/2 returns expected field mappings" do
      schema = V1.get(%V1{event_tags: "__tags__"}, [])

      assert schema.event_data == "data"
      assert schema.event_id == "messageId"
      assert schema.event_metadata == "metadata"
      assert schema.event_tags == "__tags__"
      assert schema.event_type == "type"
      assert schema.event_store_position == "globalPosition"
      assert schema.event_store_timestamp == "created"
      assert schema.event_stream_id == "streamName"
      assert schema.event_stream_position == "streamPosition"
    end

    test "default_options/0" do
      assert %{event_tags: "__tags__"} = V1.default_options()
    end

    test "custom event_tags option" do
      schema = V1.get(%V1{event_tags: "custom_tags"}, [])
      assert schema.event_tags == "custom_tags"
    end
  end

  describe "Kurrent.V1" do
    alias Fact.Seam.EventSchema.Kurrent.V1

    test "get/2 returns expected field mappings" do
      schema = V1.get(%V1{event_tags: "__Tags__"}, [])

      assert schema.event_data == "Data"
      assert schema.event_id == "EventId"
      assert schema.event_metadata == "Metadata"
      assert schema.event_tags == "__Tags__"
      assert schema.event_type == "EventType"
      assert schema.event_store_position == "Position"
      assert schema.event_store_timestamp == "Created"
      assert schema.event_stream_id == "EventStreamId"
      assert schema.event_stream_position == "EventNumber"
    end

    test "default_options/0" do
      assert %{event_tags: "__Tags__"} = V1.default_options()
    end

    test "custom event_tags option" do
      schema = V1.get(%V1{event_tags: "MyTags"}, [])
      assert schema.event_tags == "MyTags"
    end
  end

  describe "Marten.V1" do
    alias Fact.Seam.EventSchema.Marten.V1

    test "get/2 returns expected field mappings" do
      schema = V1.get(%V1{event_metadata: "__metadata__", event_tags: "__tags__"}, [])

      assert schema.event_data == "data"
      assert schema.event_id == "id"
      assert schema.event_metadata == "__metadata__"
      assert schema.event_tags == "__tags__"
      assert schema.event_type == "type"
      assert schema.event_store_position == "seq_id"
      assert schema.event_store_timestamp == "timestamp"
      assert schema.event_stream_id == "stream_id"
      assert schema.event_stream_position == "version"
    end

    test "default_options/0" do
      assert %{event_metadata: "__metadata__", event_tags: "__tags__"} = V1.default_options()
    end

    test "custom options" do
      schema = V1.get(%V1{event_metadata: "meta", event_tags: "tags"}, [])
      assert schema.event_metadata == "meta"
      assert schema.event_tags == "tags"
    end
  end
end
