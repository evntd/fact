defmodule Fact.EventTypeIndexer do
  use Fact.EventIndexer, :event_type
  
  @impl true
  def index(event, _state), do: event[@event_type]
end
