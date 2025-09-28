defmodule Fact.EventStreamIndexer do
  use Fact.EventIndexer, path: :event_stream

  @impl true
  def index_event(event, _opts), do: event[@event_stream]
end
