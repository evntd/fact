defmodule Fact.DatabaseSupervisor do
  use Supervisor
  
  def child_spec(opts) do
    context = Keyword.fetch!(opts, :context)
    %{
      id: {__MODULE__, context.database_id},
      start: {__MODULE__, :start_link, [[context: context]]},
      type: :supervisor
    }
  end

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
      {Fact.Database, context: context, name: Fact.Context.via(context, Fact.Database)},
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
