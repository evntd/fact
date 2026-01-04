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

    Supervisor.start_link(__MODULE__, context, name: Fact.Context.supervisor(database_id))
  end

  @impl true
  def init(%Fact.Context{database_id: database_id, database_name: database_name} = context) do
    # Store the context by id and name within the registry for lookups when needed.
    Registry.register(Fact.Registry, {:context, database_id}, context)
    Registry.register(Fact.Registry, {:context, database_name}, context)
    # Store the id by name.
    Registry.register(Fact.Registry, {:id, database_name}, database_id)

    children = [
      {Registry, keys: :unique, name: Fact.Context.registry(database_id)},
      {Phoenix.PubSub, name: Fact.Context.pubsub(database_id)},
      {Fact.EventPublisher,
       database_id: database_id, name: Fact.Context.via(database_id, Fact.EventPublisher)},
      {Fact.Database,
       database_id: database_id, name: Fact.Context.via(database_id, Fact.Database)},
      {Fact.EventLedger,
       database_id: database_id, name: Fact.Context.via(database_id, Fact.EventLedger)},
      {DynamicSupervisor,
       strategy: :one_for_one,
       name: Fact.Context.via(database_id, Fact.EventStreamWriterSupervisor)}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
