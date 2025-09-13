defmodule Fact.EventStreamIndexer do
  use Fact.EventIndexer
  
  @impl true 
  def index_event(event, _state), do: event[@event_stream]  
end
