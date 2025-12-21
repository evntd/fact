defmodule Fact.EventDataIndexer do
  @moduledoc """
  Index events by the values of a specified key within the event data.
  """
  use Fact.EventIndexer

  @doc """
  Retrieves the value for the configured `:key` from the event's data payload.

  ### Options

    * `:key` — required, specified the field to lookup within the event data

  ### Examples

      iex> event = %{
      ...>   "event_type" => "ClutchLaid", 
      ...>   "event_data" => %{"turtle_id" => "t1", "clutch_id" => "c1", "eggs" => 42}, 
      ...>   "event_tags" => ["turtle:t1", "clutch:c1"], 
      ...>   "stream_id" => "turtle_mating-1234",
      ...>   "stream_position" => 3
      ...> }
      iex> Fact.EventDataIndexer.index_event(event, [key: "eggs"])
      "42"

      iex> event = %{
      ...>   "event_type" => "EggHatched", 
      ...>   "event_data" => %{"turtle_id" => "t2", "clutch_id" => "c1"}, 
      ...>   "event_tags" => ["turtle:t2", "clutch:c1"], 
      ...> } 
      iex> Fact.EventDataIndexer.index_event(event, [key: "turtle_id"])
      "t2"

      iex> event = %{
      ...>   "event_type" => "DatabaseCreated", 
      ...>   "event_data" => %{"database_id" => "RVX27QR6PFDORJZF24C4DIICSQ"}, 
      ...>   "stream_id" => "__fact", 
      ...>   "stream_position" => "1"
      ...> }
      iex> Fact.EventDataIndexer.index_event(event, [key: "turtle_id"])
      nil

  """
  @impl true
  def index_event(%{@event_data => data} = _event, opts) do
    unless is_nil(val = data[Keyword.get(opts, :key)]) do
      to_string(val)
    else
      nil
    end
  end

  def index_event(_event, _opts), do: nil
end
