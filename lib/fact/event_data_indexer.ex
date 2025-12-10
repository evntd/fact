defmodule Fact.EventDataIndexer do
  @moduledoc """
  An event indexer implementation that extracts index values from an event's
  `data` payload.

  This module uses `Fact.EventIndexer` and implements the `index_event/2`
  callback. It retrieves a specific key from the event's data map and uses it
  as the value for indexing. If the key is not present, it returns `nil`.

  ## Usage

  This indexer is typically used when you want to build lookup indexes based on
  fields inside the event body itself. To configure it, provide the desired key
  in the options passed to `index_event/2`.

  For example, if the event data contains `"user_id"`, an index could be built
  against that value by passing `key: "user_id"` in the options.
  """
  use Fact.EventIndexer

  @impl true
  @doc """
  Retrieves the value for the configured `:key` from the event's data payload.

  ## Parameters

    * `event` — an event.
    * `opts` — indexing options.
      * `:key` — required, specified the field to lookup within the event data

  ## Returns

    * the value associated with the configured key, if it exists in the data
    * `nil` if the key is not present

  ## Examples

      iex> event = %{"event_type" => "UserRegistered", "event_data" => %{"user_id" => 123}}
      iex> Fact.EventDataIndexer.index_event(event, key: "user_id")
      "123"

      iex> event = %{"event_type" => "UserRegistered", "event_data" => %{"user_id" => 123}}
      iex> Fact.EventDataIndexer.index_event(event, key: "order_id")
      nil

  """
  def index_event(%{@event_data => data} = _event, opts) do
    key = Keyword.fetch!(opts, :key)

    case Map.has_key?(data, key) do
      true -> Map.get(data, key) |> to_string()
      false -> nil
    end
  end
end
