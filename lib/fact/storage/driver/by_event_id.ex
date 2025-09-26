defmodule Fact.Storage.Driver.ByEventId do
  @moduledoc false
  use Fact.Storage.Driver
  use Fact.EventKeys

  def prepare_record(event) do
    record = JSON.encode!(event)
    record_id = event[@event_id]
    {record_id, record}
  end

  def record_id_length(), do: 32
end
