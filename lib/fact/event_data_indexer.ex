defmodule Fact.EventDataIndexer do
  use Fact.EventIndexer
  
  @impl true 
  def index_event(%{@event_data => data}, {_, key}) do
    case Map.has_key?(data, key) do
      true -> Map.get(data, key)
      false -> nil
    end
  end
end
