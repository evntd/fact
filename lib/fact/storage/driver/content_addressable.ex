defmodule Fact.Storage.Driver.ContentAddressable do
  @moduledoc false
  use Fact.Storage.Driver

  @hash_algorithm :sha
  # Its 40, but might as well compute it at compile time.
  @record_id_length :crypto.hash(@hash_algorithm, "") |> Base.encode16() |> String.length()

  def prepare_record(event) do
    encoded_event = Fact.Storage.Format.Json.encode(event)
    event_id = :crypto.hash(@hash_algorithm, encoded_event) |> Base.encode16(case: :lower)
    {event_id, encoded_event}
  end

  def record_id_length(), do: @record_id_length
end
