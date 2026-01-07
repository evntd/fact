defmodule Fact.EventTypeIndexer do
  @moduledoc """
  Index events by their event type.
  """
  use Fact.EventIndexer

  @doc """
  Extracts the type of the event.
    
      iex> event = %{
      ...>   "event_type" => "ClutchLaid", 
      ...>   "event_data" => %{"turtle_id" => "t1", "clutch_id" => "c1", "eggs" => 42}, 
      ...>   "event_tags" => ["turtle:t1", "clutch:c1"], 
      ...>   "stream_id" => "turtle_mating-1234",
      ...>   "stream_position" => 3
      ...> }
      iex> Fact.EventTypeIndexer.index_event(event, [])
      "ClutchLaid"

      iex> event = %{
      ...>   "event_type" => "EggHatched", 
      ...>   "event_data" => %{"turtle_id" => "t2", "clutch_id" => "c1"}, 
      ...>   "event_tags" => ["turtle:t2", "clutch:c1"], 
      ...> } 
      iex> Fact.EventTypeIndexer.index_event(event, [])
      "EggHatched"

      iex> event = %{
      ...>   "event_type" => "DatabaseCreated", 
      ...>   "event_data" => %{"database_id" => "RVX27QR6PFDORJZF24C4DIICSQ"}, 
      ...>   "stream_id" => "__fact", 
      ...>   "stream_position" => "1"
      ...> }
      iex> Fact.EventTypeIndexer.index_event(event, [])
      "DatabaseCreated"
  """
  @impl true
  def index_event(schema, event, _opts), do: event[schema.event_type]
end
