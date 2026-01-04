defmodule Fact.EventStreamIndexer do
  @moduledoc """
  Index events by their event stream if specified.
  """
  use Fact.EventIndexer

  @doc """
  Extracts the stream name of the event.
    
  ### Examples

      iex> event = %{
      ...>   "event_type" => "ClutchLaid", 
      ...>   "event_data" => %{"turtle_id" => "t1", "clutch_id" => "c1", "eggs" => 42}, 
      ...>   "event_tags" => ["turtle:t1", "clutch:c1"], 
      ...>   "stream_id" => "turtle_mating-1234",
      ...>   "stream_position" => 3
      ...> }
      iex> Fact.EventStreamIndexer.index_event(event, [])
      "turtle_mating"

      iex> event = %{
      ...>   "event_type" => "EggHatched", 
      ...>   "event_data" => %{"turtle_id" => "t2", "clutch_id" => "c1"}, 
      ...>   "event_tags" => ["turtle:t2", "clutch:c1"], 
      ...> } 
      iex> Fact.EventStreamIndexer.index_event(event, [])
      nil

      iex> event = %{
      ...>   "event_type" => "DatabaseCreated", 
      ...>   "event_data" => %{"database_id" => "RVX27QR6PFDORJZF24C4DIICSQ"}, 
      ...>   "stream_id" => "__fact", 
      ...>   "stream_position" => "1"
      ...> }
      iex> Fact.EventStreamIndexer.index_event(event, [])
      "__fact"
  """
  @impl true
  @spec index_event(event :: Fact.Types.event_record(), Fact.EventIndexer.indexer_options()) ::
          Fact.EventIndexer.index_event_result()
  def index_event(event, _opts), do: event[@event_stream]

  @doc """
  Utility method to determine the last position within an event stream. 
  Returns `0` if the event stream does not exist.
    
  This is similar to `Fact.Storage.last_store_position/1`, but for a streams.
  """
  @spec last_stream_position(Fact.Context.t(), Fact.Types.event_stream()) :: non_neg_integer()
  def last_stream_position(database_id, event_stream) do
    with {:ok, context} <- Fact.Supervisor.get_context(database_id) do
      unless(
        is_nil(event = Fact.IndexFile.read_last_event(context, {__MODULE__, nil}, event_stream)),
        do: Fact.RecordFile.Schema.get_event_stream_position(context, event),
        else: 0
      )
    end
  end
end
