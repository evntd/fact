defmodule Fact.Storage.Driver.ByEventId do
  @moduledoc """
  A `Fact.Storage.Driver` implementation that uses the event's own ID as the
  storage record identifier.

  This driver assumes that every event contains an id defined by
  `@event_id` (provided by `use Fact.EventKeys`). When preparing a record for
  storage, the event is encoded and returned alongside its event ID as the
  record identifier.
  """

  @behaviour Fact.Storage.Driver
  use Fact.EventKeys

  @record_id_length 32

  @impl true
  @doc """
  Prepares a storage record using the event's own ID as the record identifier.

  ## Parameters

    * `event` — a map expected to contain an event ID under the key specified
      by `@event_id`.
    * `encode` — a function that receives the event and returns its encoded
      binary representation.

  ## Returns

    A tuple `{record_id, record_data}` where:

    * `record_id` — the event's ID
    * `record_data` — the encoded event data

  ## Examples

      iex> encode = fn evt -> Fact.Json.encode!(evt) end
      iex> event = %{"event_id" => "abc123", "event_data" => %{}}
      iex> Fact.Storage.Driver.ByEventId.prepare_record(event, encode)
      {:error, {:invalid_record_id, "abc123"}}

  """

  def prepare_record(event, encode) do
    record = encode.(event)
    record_id = event[@event_id]

    if Fact.Uuid.valid?(record_id),
      do: {:ok, record_id, record},
      else: {:error, {:invalid_record_id, record_id}}
  end

  @impl true
  @doc """
  Returns the expected fixed length of record identifiers produced by this driver.

  The length is determined at compile time by generating a hex-encoded UUIDv4
  and measuring its string length.

  ## Returns

    * an integer representing the record ID length (typically `40`)

  """
  def record_id_length(), do: @record_id_length
end
