defmodule Fact.EventStreamsIndexer do
  @moduledoc false
  use Fact.EventIndexer, path: :event_streams

  @impl true
  def index_event(%{@event_stream_position => 1, @event_stream => event_stream}, _opts),
    do: event_stream

  def index_event(_event, _opts), do: nil
end
