defmodule Fact.EventStreamsByCategoryIndexer do
  @moduledoc """
  Indexes the first event of each event stream by the stream **category**. 

  Similar to the `Fact.EventStreamCategoryIndexer` this splits the event stream using a specified separator and returns 
  the first segment, but behaves like the `Fact.EventStreamsIndexer` and only indexes the first event of each stream.
    
  This results in creating an index file per-category, each containing the first event in for each stream in the
  category. It is common in systems for all instances of an Aggregate root to write to the same "category", this indexer
  makes it easy to find all the instances of that type (e.g. Get All Orders, Get All Customers, etc.).
  """
  use Fact.EventIndexer

  @typedoc """
  Custom option values passed to the `c:Fact.EventIndexer.index_event/2` callback function.
  """
  @type option :: {:separator, String.t()} | Fact.EventIndexer.indexer_option()

  @typedoc """
  Custom options passed to the `c:Fact.EventIndexer.index_event/2` callback function.
  """
  @type options :: [option()]

  @default_separator "-"

  @doc """
  Extracts the stream category from the first event of each event stream.
    
  ### Options
    
    * `:separator` - optional delimiter used to split the stream name.
      Defaults to "-".

  ### Examples

      iex> event = %{
      ...>   "event_type" => "ClutchLaid", 
      ...>   "event_data" => %{"turtle_id" => "t1", "clutch_id" => "c1", "eggs" => 42}, 
      ...>   "event_tags" => ["turtle:t1", "clutch:c1"], 
      ...>   "stream_id" => "turtle_mating-1234",
      ...>   "stream_position" => 3
      ...> }
      iex> Fact.EventStreamsByCategoryIndexer.index_event(event, [])
      nil

      iex> event = %{
      ...>   "event_type" => "EggHatched", 
      ...>   "event_data" => %{"turtle_id" => "t2", "clutch_id" => "c1"}, 
      ...>   "event_tags" => ["turtle:t2", "clutch:c1"], 
      ...> }
      iex> Fact.EventStreamsByCategoryIndexer.index_event(event, [])
      nil

      iex> event = %{
      ...>   "event_type" => "DatabaseCreated", 
      ...>   "event_data" => %{"database_id" => "RVX27QR6PFDORJZF24C4DIICSQ"}, 
      ...>   "stream_id" => "__fact", 
      ...>   "stream_position" => 1
      ...> }
      iex> Fact.EventStreamsByCategoryIndexer.index_event(event, [])
      "__fact"
  """
  @impl true
  def index_event(schema, event, opts) do
    if (stream = event[schema.event_stream_id]) && 1 == event[schema.event_stream_position] do
      separator = Keyword.get(opts, :separator, @default_separator)
      stream |> String.split(separator, parts: 2) |> List.first()
    end
  end
end
