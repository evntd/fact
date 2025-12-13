defmodule Fact.Storage.Driver.ByEventId.Test do
  use ExUnit.Case, async: true
  doctest Fact.Storage.Driver.ByEventId

  # Helper function for encoding
  def encode(event), do: Fact.Json.encode!(event)

  test "`record_id_length/0` should return length of hex formatted uuid" do
    assert 32 == Fact.Storage.Driver.ByEventId.record_id_length()
  end

  test "`prepare_record/2` should return tuple of event id and encoded event" do
    event_id = Fact.Uuid.v4()

    event = %{
      "event_id" => event_id,
      "event_type" => "TestEvent",
      "event_data" => %{},
      "event_metadata" => %{}
    }

    assert {:ok, event_id,
            "{\"event_data\":{},\"event_id\":\"#{event_id}\",\"event_metadata\":{},\"event_type\":\"TestEvent\"}"} ==
             Fact.Storage.Driver.ByEventId.prepare_record(event, &encode/1)
  end

  test "`prepare_record/2` should fail when event id is not a valid UUID" do
    event_id = "thisisnotavaliduuid"

    event = %{
      "event_id" => event_id,
      "event_type" => "TestEvent",
      "event_data" => %{},
      "event_metadata" => %{}
    }

    assert {:error, {:invalid_record_id, event_id}} ==
             Fact.Storage.Driver.ByEventId.prepare_record(event, &encode/1)
  end
end
