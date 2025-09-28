defmodule Fact.EventTypeIndexer do
  use Fact.EventIndexer, path: :event_type

  @impl true
  def index_event(event, _opts), do: event[@event_type]
end
