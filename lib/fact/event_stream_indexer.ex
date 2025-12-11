defmodule Fact.EventStreamIndexer do
  @moduledoc """
  An event indexer that retrieves the stream name of an event and provides
  utilities for accessing the last position within a stream.

  This module implements the `Fact.EventIndexer` behaviour and returns the
  value stored under the event's stream field (as defined by the `@event_stream`
  attribute). 

  Additionally, it provides a helper function to determine the last event
  position in a given stream, which can be useful for appending events or
  tracking stream progress.
  """
  use Fact.EventIndexer

  @doc """
  Retrieves the stream name of the given event.

  ## Parameters

    * `event` — an event.
    * `opts` — indexing options.

  ## Returns

    * the event's stream name if present
    * `nil` if the stream field is missing

  ## Examples

      iex> event = %{"stream" => "user-123"}
      iex> Fact.EventStreamIndexer.index_event(event, [])
      "user-123"

      iex> Fact.EventStreamIndexer.index_event(%{}, [])
      nil

  """
  @impl true
  def index_event(event, _opts), do: event[@event_stream]

  @doc """
  Returns the last position in a given event stream.

  Queries the index for the given `event_stream` in reverse (backward)
  order to find the most recent event. Returns `0` if the stream is empty.

  ## Parameters

    * `instance` — the storage instance to query
    * `event_stream` — the stream name to check

  ## Returns

    * the last `stream_position` for the stream
    * `0` if the stream has no events

  ## Examples

      iex> Fact.EventStreamIndexer.last_stream_position(storage_instance, "user-123")
      42

      iex> Fact.EventStreamIndexer.last_stream_position(storage_instance, "new-stream")
      0

  """
  def last_stream_position(instance, event_stream) do
    last_record_id =
      Fact.Storage.read_index(instance, __MODULE__, event_stream, direction: :backward)
      |> Enum.at(0, :none)

    case last_record_id do
      :none ->
        0

      record_id ->
        {_, event} = Fact.Storage.read_event!(instance, record_id)
        event[@event_stream_position]
    end
  end
end
