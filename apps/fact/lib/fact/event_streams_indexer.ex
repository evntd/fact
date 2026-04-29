defmodule Fact.EventStreamsIndexer do
  @moduledoc """
  An event indexer which indexes the first event of each event stream.
  """
  use Fact.EventIndexer

  @typedoc """
  The id for a Fact.EventStreamsIndexer.
  """
  @type id :: {Fact.EventStreamsIndexer, nil}

  @index "index"

  @doc """
  Returns "index" when the first event of an event stream is indexed.
    
  This is done so that a single index file is written that contains all the first events. If the stream name was
  returned instead, an index file would be created for each stream, and each index file would contain a single
  record id.  
    
  ### Examples

      iex> event = %{
      ...>   "event_type" => "ClutchLaid", 
      ...>   "event_data" => %{"turtle_id" => "t1", "clutch_id" => "c1", "eggs" => 42}, 
      ...>   "event_tags" => ["turtle:t1", "clutch:c1"], 
      ...>   "stream_id" => "turtle_mating-1234",
      ...>   "stream_position" => 3
      ...> }
      iex> Fact.EventStreamsIndexer.index_event(event, [])
      nil

      iex> event = %{
      ...>   "event_type" => "EggHatched", 
      ...>   "event_data" => %{"turtle_id" => "t2", "clutch_id" => "c1"}, 
      ...>   "event_tags" => ["turtle:t2", "clutch:c1"], 
      ...> }
      iex> Fact.EventStreamsIndexer.index_event(event, [])
      nil

      iex> event = %{
      ...>   "event_type" => "DatabaseCreated", 
      ...>   "event_data" => %{"database_id" => "RVX27QR6PFDORJZF24C4DIICSQ"}, 
      ...>   "stream_id" => "__fact", 
      ...>   "stream_position" => 1
      ...> }
      iex> Fact.EventStreamsIndexer.index_event(event, [])
      "index"
  """
  @impl true
  def index_event(schema, event, _opts) do
    if event[schema.event_stream_position] == 1, do: @index
  end
end
