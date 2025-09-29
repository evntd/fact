defmodule Fact.EventStorage.Driver.ContentAddressable do
  @moduledoc false
  @behaviour Fact.EventStorage.Driver

  @hash_algorithm :sha
  # Its 40, but might as well compute it at compile time.
  @record_id_length :crypto.hash(@hash_algorithm, "") |> Base.encode16() |> String.length()

  @impl true
  def prepare_record(event, encode) do
    encoded_event = encode.(event)
    event_id = :crypto.hash(@hash_algorithm, encoded_event) |> Base.encode16(case: :lower)
    {event_id, encoded_event}
  end

  @impl true
  def record_id_length(), do: @record_id_length
end
