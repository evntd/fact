defmodule Fact.EventTypeIndexer do
  use Fact.EventIndexer
  
  @impl true
  def index_event(event, _opts), do: event[@event_type]
end
