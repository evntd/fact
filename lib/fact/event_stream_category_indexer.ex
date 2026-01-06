defmodule Fact.EventStreamCategoryIndexer do
  @moduledoc """
  Indexes events by the *category* portion of an event stream, by splitting the string on a 
  specified separator and returns the first segment.
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
  Extracts a category from an event stream id.

  ### Options

    * `:separator` - optional delimiter used to split the stream name.
        Defaults to `"-"`.

  ### Examples 

      iex> event = %{
      ...>   "event_type" => "ClutchLaid", 
      ...>   "event_data" => %{"turtle_id" => "t1", "clutch_id" => "c1", "eggs" => 42}, 
      ...>   "event_tags" => ["turtle:t1", "clutch:c1"], 
      ...>   "stream_id" => "turtle_mating-1234"
      ...> }
      iex> Fact.EventStreamCategoryIndexer.index_event(event, [])
      "turtle_mating"

      iex> event = %{
      ...>   "event_type" => "EggHatched", 
      ...>   "event_data" => %{"turtle_id" => "t2", "clutch_id" => "c1"}, 
      ...>   "event_tags" => ["turtle:t2", "clutch:c1"], 
      ...> }
      iex> Fact.EventStreamCategoryIndexer.index_event(event, [])
      nil

      iex> event = %{
      ...>   "event_type" => "DatabaseCreated", 
      ...>   "event_data" => %{"database_id" => "RVX27QR6PFDORJZF24C4DIICSQ"}, 
      ...>   "stream_id" => "__fact", 
      ...>   "stream_position" => 1
      ...> }
      iex> Fact.EventStreamCategoryIndexer.index_event(event, [])
      "__fact"

  """
  @impl true
  def index_event(schema, event, opts) do
    unless is_nil(stream = event[schema.event_stream_id]) do
      separator = Keyword.get(opts, :separator, @default_separator)
      stream |> String.split(separator, parts: 2) |> List.first()  
    end
  end
end
