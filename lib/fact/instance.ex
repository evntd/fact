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

  def storage(%__MODULE__{} = instance) do
    via(instance, Fact.Storage)
  end

  def storage_table(%__MODULE__{database_id: id}) do
    Module.concat(Fact.Storage, id)
  end

  def supervisor(%__MODULE__{database_id: id}) do
    Module.concat(Fact.Supervisor, id)
  end

  def via(%__MODULE__{} = instance, key) do
    {:via, Registry, {registry(instance), key}}
  end

  # === PATHS

  def database_path(%__MODULE__{} = instance) do
    instance.manifest.database_path
  end

  def events_path(%__MODULE__{} = instance) do
    instance.manifest.events_path
  end

  def indices_path(%__MODULE__{} = instance) do
    instance.manifest.indices_path
  end

  def ledger_path(%__MODULE__{} = instance) do
    instance.manifest.ledger_path
  end
end
