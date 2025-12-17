defmodule Fact.Instance do
  @type t :: %__MODULE__{
          database_id: String.t()
        }

  @enforce_keys [:database_id]
  defstruct [:database_id, :manifest]

  def new(manifest) when is_map(manifest) do
    %__MODULE__{
      database_id: manifest.database_id,
      manifest: manifest
    }
  end

  def event_indexer_manager(%__MODULE__{} = instance) do
    via(instance, Fact.EventIndexerManager)
  end

  def event_indexer_supervisor(%__MODULE__{} = instance) do
    via(instance, Fact.EventIndexerSupervisor)
  end

  def event_ledger(%__MODULE__{} = instance) do
    via(instance, Fact.EventLedger)
  end

  def event_stream_writer_supervisor(%__MODULE__{} = instance) do
    via(instance, Fact.EventStreamWriterSupervisor)
  end

  def pubsub(%__MODULE__{database_id: id}) do
    Module.concat(Fact.PubSub, id)
  end

  def registry(%__MODULE__{database_id: id}) do
    Module.concat(Fact.Registry, id)
  end

  def supervisor(%__MODULE__{database_id: id}) do
    Module.concat(Fact.Supervisor, id)
  end

  def via(%__MODULE__{} = instance, key) do
    {:via, Registry, {registry(instance), key}}
  end

  # === PATHS

  @indexer_checkpoint_filename ".checkpoint"

  def database_path(%__MODULE__{} = instance) do
    instance.manifest.database_path
  end

  def events_path(%__MODULE__{} = instance) do
    instance.manifest.events_path
  end

  def indexer_checkpoint_path(%__MODULE__{} = instance, indexer) do
    Path.join(indexer_path(instance, indexer), @indexer_checkpoint_filename)
  end

  def indexer_path(%__MODULE__{} = instance, indexer_mod) when is_atom(indexer_mod) do
    Path.join(indices_path(instance), to_string(indexer_mod))
  end

  def indexer_path(%__MODULE__{} = instance, {indexer_mod, index} = indexer)
      when is_tuple(indexer) do
    Path.join([indices_path(instance), to_string(indexer_mod), to_string(index)])
  end

  def indices_path(%__MODULE__{} = instance) do
    instance.manifest.indices_path
  end

  def ledger_path(%__MODULE__{} = instance) do
    instance.manifest.ledger_path
  end

  def record_path(%__MODULE__{} = instance, record_id) do
    Path.join(events_path(instance), record_id)
  end

  # == OLD

  def driver(%__MODULE__{} = instance) do
    instance.manifest.records.old_driver
  end

  def format(%__MODULE__{} = instance) do
    instance.manifest.records.old_format
  end

  def indexer_config(%__MODULE__{} = instance, indexer_mod) when is_atom(indexer_mod) do
    Enum.find(instance.manifest.indexers, fn i -> i.module === indexer_mod end)
  end

  def indexer_config(%__MODULE__{} = instance, {indexer_mod, _index} = indexer)
      when is_tuple(indexer) do
    indexer_config(instance, indexer_mod)
  end

  def index_path_encoder(%__MODULE__{} = instance, indexer) do
    config = indexer_config(instance, indexer)
    path = indexer_path(instance, indexer)

    fn key ->
      Path.join(path, encode_key(key, config.old_encoding))
    end
  end

  defp encode_key(value, :raw), do: to_string(value)

  defp encode_key(value, {:hash, algo}),
    do: :crypto.hash(algo, to_string(value)) |> Base.encode16(case: :lower)
end
