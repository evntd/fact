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

    Supervisor.start_link(__MODULE__, context, name: Fact.Registry.supervisor(database_id))
  end

  @impl true
  def init(%Fact.Context{database_id: database_id} = context) do
    Fact.Registry.register(context)

    children = [
      {Registry, keys: :unique, name: Fact.Registry.registry(database_id)},
      {Phoenix.PubSub, name: Fact.Registry.pubsub(database_id)},
      {Fact.EventPublisher,
       database_id: database_id, name: Fact.Registry.via(database_id, Fact.EventPublisher)},
      {Fact.Database,
       database_id: database_id, name: Fact.Registry.via(database_id, Fact.Database)},
      {Fact.EventLedger,
       database_id: database_id, name: Fact.Registry.via(database_id, Fact.EventLedger)},
      {Fact.EventStreamIndexer,
       database_id: database_id, name: Fact.Registry.via(database_id, Fact.EventStreamIndexer)},
      {Fact.EventTagsIndexer,
       database_id: database_id, name: Fact.Registry.via(database_id, Fact.EventTagsIndexer)},
      {Fact.EventTypeIndexer,
       database_id: database_id, name: Fact.Registry.via(database_id, Fact.EventTypeIndexer)},
      {Fact.EventStreamCategoryIndexer,
       database_id: database_id,
       name: Fact.Registry.via(database_id, Fact.EventStreamCategoryIndexer)},
      {Fact.EventStreamsIndexer,
       database_id: database_id, name: Fact.Registry.via(database_id, Fact.EventStreamsIndexer)},
      {Fact.EventStreamsByCategoryIndexer,
       database_id: database_id,
       name: Fact.Registry.via(database_id, Fact.EventStreamsByCategoryIndexer)},
      {DynamicSupervisor,
       strategy: :one_for_one,
       name: Fact.Registry.via(database_id, Fact.EventStreamWriterSupervisor)}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
