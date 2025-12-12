defmodule Fact.Supervisor do
  use Supervisor
  import Fact.Names
  require Logger

  @default :""

  def start_link(opts) do
    instance = Keyword.get(opts, :instance, @default)
    init_arg = Keyword.put_new(opts, :instance, instance)
    Supervisor.start_link(__MODULE__, init_arg, name: :"#{instance}.#{__MODULE__}")
  end

  @impl true
  def init(opts) do
    {storage_opts, _} = Keyword.split(opts, [:instance, :path, :driver, :format])
    instance = Keyword.fetch!(storage_opts, :instance)
    indexers = Keyword.get(opts, :indexers, default_indexers(instance))

    children = [
      {Registry, keys: :unique, name: registry(instance)},
      {Registry, keys: :unique, name: event_stream_registry(instance)},
      {Registry, keys: :unique, name: event_indexer_registry(instance)},
      {Fact.EventPublisher, []},
      {Fact.Storage, storage_opts},
      {Fact.EventLedger, [instance: instance]},
      {Fact.EventIndexerManager, [instance: instance, indexers: indexers]},
      {DynamicSupervisor,
       strategy: :one_for_one, name: via(instance, Fact.EventStreamWriterSupervisor)}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp default_indexers(instance) do
    default_opts = [instance: instance]

    [
      {Fact.EventDataIndexer, default_opts ++ [encoding: {:hash, :sha}, enabled: false]},
      {Fact.EventStreamIndexer, default_opts},
      {Fact.EventTagsIndexer, default_opts},
      {Fact.EventTypeIndexer, default_opts},      
      {Fact.EventStreamCategoryIndexer, default_opts},
      {Fact.EventStreamsByCategoryIndexer, default_opts},
      {Fact.EventStreamsIndexer, default_opts}
    ]
  end
end
