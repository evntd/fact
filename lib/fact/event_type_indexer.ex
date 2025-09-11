defmodule Fact.EventTypeIndexer do
  use Fact.Indexer, :event_type
  
  @impl true
  def index(event), do: event["stream"]
end
