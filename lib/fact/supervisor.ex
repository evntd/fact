defmodule Fact.Supervisor do
  use Supervisor

  require Logger

  @default :""

  def start_link(instance: instance) do
    manifest = instance.manifest

    init_opts = [
      instance: instance,
      path: manifest.database_path,
      driver: manifest.records.old_driver,
      format: manifest.records.old_format,
      indexers:
        Enum.map(manifest.indexers, fn x ->
          {mod, opts} = x.old_spec

          {mod,
           opts
           |> Keyword.replace(:instance, instance)
           |> Keyword.put(:name, Fact.Instance.via(instance, mod))}
        end)
    ]

    Logger.debug("[Fact.Supervisor.start_link/1] init_opts = #{inspect(init_opts)}")

    Supervisor.start_link(__MODULE__, init_opts, name: Fact.Instance.supervisor(instance))
  end

  def start_link(opts) do
    instance = Keyword.get(opts, :instance, @default)
    init_arg = Keyword.put_new(opts, :instance, instance)
    Supervisor.start_link(__MODULE__, init_arg, name: :"#{instance}.#{__MODULE__}")
  end

  @impl true
  def init(opts) do
    {storage_opts, _} = Keyword.split(opts, [:instance, :path, :driver, :format])
    instance = Keyword.fetch!(storage_opts, :instance)
    indexers = Keyword.get(opts, :indexers, [])

    children = [
      {Registry, keys: :unique, name: Fact.Instance.registry(instance)},
      {DynamicSupervisor,
       strategy: :one_for_one, name: Fact.Instance.event_indexer_supervisor(instance)},
      {Phoenix.PubSub, name: Fact.Instance.pubsub(instance)},
      {Fact.Storage, storage_opts ++ [name: Fact.Instance.storage(instance)]},
      {Fact.EventLedger, [instance: instance, name: Fact.Instance.event_ledger(instance)]},
      {Fact.EventIndexerManager,
       [
         name: Fact.Instance.event_indexer_manager(instance),
         instance: instance,
         indexers: indexers
       ]},
      {DynamicSupervisor,
       strategy: :one_for_one, name: Fact.Instance.event_stream_writer_supervisor(instance)}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
