defmodule Fact.Supervisor do
  @moduledoc false
  use Supervisor
  import Fact.Names
  require Logger

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    Supervisor.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(opts) do
    ledger_opts = Keyword.fetch!(opts, :ledger)
    storage_opts = Keyword.fetch!(opts, :storage)
    {indexer_opts, _} = Keyword.split(opts, [:indexers])

    instance = Keyword.fetch!(opts, :name)

    Logger.debug(inspect(indexer_opts))

    children = [
      {Registry, keys: :unique, name: registry(instance)},
      {Registry, keys: :unique, name: event_stream_registry(instance)},
      {Registry, keys: :unique, name: event_indexer_registry(instance)},
      {Fact.EventPublisher, []},
      {Fact.Storage, Keyword.put(storage_opts, :instance, instance)},
      {Fact.EventLedger, Keyword.put(ledger_opts, :instance, instance)},
      {Fact.EventIndexerManager, Keyword.put(indexer_opts, :instance, instance)},
      {DynamicSupervisor,
       strategy: :one_for_one, name: via(instance, Fact.EventStreamWriterSupervisor)}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
