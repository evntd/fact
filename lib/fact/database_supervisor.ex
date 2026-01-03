defmodule Fact.DatabaseSupervisor do
  use Supervisor

  def start_link(context: context) do
    %Fact.Context{database_id: database_id} = context

    Supervisor.start_link(__MODULE__, context,
      name: Module.concat(Fact.DatabaseSupervisor, database_id)
    )
  end

  @impl true
  def init(%Fact.Context{} = context) do
    children = [
      {Registry, keys: :unique, name: Fact.Context.registry(context)},
      {Fact.LockOwner,
       context: context, mode: :run, name: Fact.Context.via(context, Fact.LockOwner)},
      {DynamicSupervisor,
       strategy: :one_for_one, name: Fact.Context.via(context, Fact.EventIndexerSupervisor)},
      {Phoenix.PubSub, name: Fact.Context.pubsub(context)},
      {Fact.EventLedger, context: context, name: Fact.Context.via(context, Fact.EventLedger)},
      {Fact.EventIndexerManager,
       context: context, name: Fact.Context.via(context, Fact.EventIndexerManager)},
      {DynamicSupervisor,
       strategy: :one_for_one, name: Fact.Context.via(context, Fact.EventStreamWriterSupervisor)}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
