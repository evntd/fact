defmodule Fact.Storage.Driver.ByEventId.Test do
  use ExUnit.Case
  doctest Fact.Storage.Driver.ByEventId

  # Helper function for encoding
  def encode(event), do: JSON.encode!(event)

  test "`record_id_length/0` should return length of hex formatted uuid" do
    assert 32 == Fact.Storage.Driver.ByEventId.record_id_length()
  end

  test "`prepare_record/2` should return tuple of event id and encoded event" do
    event_id = UUID.uuid4(:hex)
    event = %{"id" => event_id, "type" => "TestEvent", "data" => %{}, "metadata" => %{}}

    assert {:ok, event_id,
            "{\"data\":{},\"id\":\"#{event_id}\",\"metadata\":{},\"type\":\"TestEvent\"}"} ==
             Fact.Storage.Driver.ByEventId.prepare_record(event, &encode/1)
  end

  test "`prepare_record/2` should fail when event id is not a valid UUID" do
    event_id = "thisisnotavaliduuid"
    event = %{"id" => event_id, "type" => "TestEvent", "data" => %{}, "metadata" => %{}}

    assert {:error, {:invalid_record_id, event_id}} ==
             Fact.Storage.Driver.ByEventId.prepare_record(event, &encode/1)
  end
end
