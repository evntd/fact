defmodule Fact.EventStreamIndexer do
  use Fact.Indexer, :event_stream
  
  @impl true 
  def index(event), do: event["type"]  
end
