defmodule Fact.Storage.Driver.ByEventId do
  @moduledoc false
  @behaviour Fact.Storage.Driver
  use Fact.EventKeys
  # Its 40, but might as well compute it at compile time.
  @record_id_length UUID.uuid4(:hex) |> String.length()

  @impl true
  def prepare_record(event, encode) do
    record = encode.(event)
    record_id = event[@event_id]
    {record_id, record}
  end

  @impl true
  def record_id_length(), do: @record_id_length
end
