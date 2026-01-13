defmodule Fact.EventDataIndexer do
  @moduledoc """
  Index events by the values of a specified key within the event data.
  """
  use Fact.EventIndexer

  @typedoc """
  The id for a Fact.EventDataIndexer.
  """
  @type id :: {Fact.EventDataIndexer, Fact.EventIndexer.indexer_key()}

  @typedoc """
  Custom option values passed to the `c:Fact.EventIndexer.index_event/3` callback function.
  """
  @type option :: {:indexer_key, String.t()} | Fact.EventIndexer.indexer_option()

  @typedoc """
  Custom options passed to the `c:Fact.EventIndexer.index_event/3` callback function.
  """
  @type options :: [option()]

  @doc """
  Retrieves the value for the configured `:indexer_key` from the event's data payload.

  ### Options

    * `:indexer_key` — required, specified the field to lookup within the event data

  ### Examples

      iex> event = %{
      ...>   "event_type" => "ClutchLaid", 
      ...>   "event_data" => %{"turtle_id" => "t1", "clutch_id" => "c1", "eggs" => 42}, 
      ...>   "event_tags" => ["turtle:t1", "clutch:c1"], 
      ...>   "stream_id" => "turtle_mating-1234",
      ...>   "stream_position" => 3
      ...> }
      iex> Fact.EventDataIndexer.index_event(event, [indexer_key: "eggs"])
      "42"

      iex> event = %{
      ...>   "event_type" => "EggHatched", 
      ...>   "event_data" => %{"turtle_id" => "t2", "clutch_id" => "c1"}, 
      ...>   "event_tags" => ["turtle:t2", "clutch:c1"], 
      ...> } 
      iex> Fact.EventDataIndexer.index_event(event, [indexer_key: "turtle_id"])
      "t2"

      iex> event = %{
      ...>   "event_type" => "DatabaseCreated", 
      ...>   "event_data" => %{"database_id" => "RVX27QR6PFDORJZF24C4DIICSQ"}, 
      ...>   "stream_id" => "__fact", 
      ...>   "stream_position" => "1"
      ...> }
      iex> Fact.EventDataIndexer.index_event(event, [indexer_key: "turtle_id"])
      nil

  """
  @impl true
  def index_event(schema, event, opts) do
    event_data = event[schema.event_data]
    indexer_key = Keyword.get(opts, :indexer_key)

    unless is_nil(value = Map.get(event_data, indexer_key)) do
      to_string(value)
    end
  end
end
