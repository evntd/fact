defmodule Fact.EventTypeIndexer do
  use Fact.Indexer
  
  @impl true
  def index, do: :event_type 
  
  @impl true
  def index_event(event), do: event["stream"]

end
