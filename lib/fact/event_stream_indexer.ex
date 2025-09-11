defmodule Fact.EventStreamIndexer do
  use Fact.EventIndexer, :event_stream
  
  @impl true 
  def index(event), do: event[@event_stream]  
end
