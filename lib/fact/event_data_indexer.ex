defmodule Fact.EventDataIndexer do
  @moduledoc """
  Indexes events by the values of a specified field within event data.
  """
  @moduledoc since: "0.1.0"
  use Fact.EventIndexer

  @typedoc """
  The id for a Fact.EventDataIndexer.
  """
  @typedoc since: "0.1.0"
  @type id :: {Fact.EventDataIndexer, Fact.EventIndexer.indexer_key()}

  @typedoc """
  Custom option values passed to the `c:Fact.EventIndexer.index_event/3` callback function.
  """
  @typedoc since: "0.1.0"
  @type option :: {:indexer_key, String.t()} | Fact.EventIndexer.indexer_option()

  @typedoc """
  Custom options passed to the `c:Fact.EventIndexer.index_event/3` callback function.
  """
  @typedoc since: "0.1.0"
  @type options :: [option()]

  @doc """
  Retrieves the value for the configured `:indexer_key` from the event's data payload.  

  ### Options

    * `:indexer_key` — required, specified the field to lookup within the event data
  """
  @doc since: "0.1.0"
  @impl true
  @spec index_event(Fact.event_schema(), Fact.event_record(), options()) :: String.t() | nil
  def index_event(schema, event, opts) do
    event_data = event[schema.event_data]
    indexer_key = Keyword.get(opts, :indexer_key)

    unless is_nil(value = get(event_data, indexer_key)) do
      to_string(value)
    end
  end

  defp get(map, key) when is_binary(key) do
    case Map.fetch(map, key) do
      {:ok, value} -> value
      :error -> Map.get(map, String.to_existing_atom(key))
    end
  rescue
    ArgumentError ->
      nil
  end
end
