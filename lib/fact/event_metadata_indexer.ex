defmodule Fact.EventMetadataIndexer do
  @moduledoc """
  Indexes events by the values of a specified field within event metadata.
  """
  @moduledoc since: "0.3.1"
  use Fact.EventIndexer

  @typedoc """
  The id for a Fact.EventMetadataIndexer.
  """
  @typedoc since: "0.3.1"
  @type id :: {Fact.EventMetadataIndexer, Fact.EventIndexer.indexer_key()}

  @typedoc """
  Custom option values passed to the `c:Fact.EventIndexer.index_event/3` callback function.
  """
  @typedoc since: "0.3.1"
  @type option :: {:indexer_key, String.t()} | Fact.EventIndexer.indexer_option()

  @typedoc """
  Custom options passed to the `c:Fact.EventIndexer.index_event/3` callback function.
  """
  @typedoc since: "0.3.1"
  @type options :: [option()]

  @doc """
  Retrieves the value for the configured `:indexer_key` from the event's metadata payload.

  ### Options

    * `:indexer_key` — required, specifies the field to lookup within the event metadata
  """
  @doc since: "0.3.1"
  @impl true
  @spec index_event(Fact.event_record_schema(), Fact.event_record(), options()) ::
          String.t() | nil
  def index_event(schema, event, opts) do
    event_metadata = event[schema.event_metadata]
    indexer_key = Keyword.get(opts, :indexer_key)

    unless is_nil(value = get(event_metadata, indexer_key)) do
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
