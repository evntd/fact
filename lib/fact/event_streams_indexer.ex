defmodule Fact.EventStreamsIndexer do
  @moduledoc """
  An event indexer that retrieves the stream name for the first event in a stream.

  This module implements the `Fact.EventIndexer` behaviour. It returns the
  stream identifier of an event **only if the event is the first in its stream**. 
  
  This indexer is useful for building indexes or metadata for stream-level
  operations, such as cataloging streams when their first event is processed.
  """
  use Fact.EventIndexer

  @impl true
  @doc """
  Returns the event stream name if the event is the first in the stream.

  ## Parameters

    * `event` — an event.
    * `opts` — indexing options
    
  ## Returns

    * the stream name if the event is the first in its stream
    * `nil` for all other events

  ## Examples

      iex> event = %{"stream_position" => 1, "stream" => "user-123"}
      iex> Fact.EventStreamsIndexer.index_event(event, [])
      "user-123"

      iex> event = %{"stream_position" => 5, "stream" => "user-123"}
      iex> Fact.EventStreamsIndexer.index_event(event, [])
      nil

      iex> Fact.EventStreamsIndexer.index_event(%{}, [])
      nil

  """
  def index_event(%{@event_stream_position => 1, @event_stream => event_stream} = _event, _opts),
    do: event_stream

  def index_event(_event, _opts), do: nil
end
