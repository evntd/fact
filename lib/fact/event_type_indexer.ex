defmodule Fact.EventTypeIndexer do
  use Fact.EventIndexer, :event_type
  
  @impl true
  def index(event), do: event[@event_type]
end
