defmodule Fact.EventStreamIndexer do
  use Fact.EventIndexer, :event_stream
  
  @impl true 
  def index(event, _state), do: event[@event_stream]  
end
