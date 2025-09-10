defmodule Fact.EventStreamIndexer do
  use Fact.Indexer
  
  @impl true
  def index, do: :event_stream
  
  @impl true 
  def index_event(event), do: event["type"]
  
end