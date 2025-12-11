defmodule Fact.EventStreamsIndexer do
  @moduledoc """
  An event indexer which indexes the first event of each event stream.
  """
  use Fact.EventIndexer

  @index "event_streams"
  
  @impl true
  @doc """
  Returns "event_streams" if the event is the first in a stream, otherwise nil.

  ## Examples

      iex> event = %{"stream_id" => "user-123", "stream_position" => 1}
      iex> Fact.EventStreamsIndexer.index_event(event, [])
      "event_streams"

      iex> event = %{"stream_id" => "user-123", "stream_position" => 5}
      iex> Fact.EventStreamsIndexer.index_event(event, [])
      nil

      iex> Fact.EventStreamsIndexer.index_event(%{}, [])
      nil

  """
  def index_event(%{@event_stream_position => 1} = _event, _opts), do: @index
  def index_event(_event, _opts), do: nil
end
