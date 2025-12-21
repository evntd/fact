defmodule Fact.Supervisor do
  use Supervisor

  require Logger

  def start_link(instance: instance) do
    init_opts = [
      instance: instance,
      indexers:
        Enum.map(instance.indexers, fn x ->
          {mod, opts} = x.old_spec

          {mod,
           opts
           |> Keyword.replace(:instance, instance)
           |> Keyword.put(:name, Fact.Instance.via(instance, mod))}
        end)
    ]

    Supervisor.start_link(__MODULE__, init_opts, name: Fact.Instance.supervisor(instance))
  end

  @impl true
  def init(opts) do
    instance = Keyword.fetch!(opts, :instance)
    indexers = Keyword.get(opts, :indexers, [])

    children = [
      {Registry, keys: :unique, name: Fact.Instance.registry(instance)},
      {Fact.LockOwner,
       instance: instance, mode: :run, name: Fact.Instance.via(instance, Fact.LockOwner)},
      {DynamicSupervisor,
       strategy: :one_for_one, name: Fact.Instance.event_indexer_supervisor(instance)},
      {Phoenix.PubSub, name: Fact.Instance.pubsub(instance)},
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
