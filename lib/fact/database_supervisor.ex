defmodule Fact.DatabaseSupervisor do
  @moduledoc """
  Supervises all processes for a single Fact database instance. 🏛️

  `Fact.DatabaseSupervisor` is the top-level supervisor for a database, responsible for:

    * Registering the database in `Fact.Registry`
    * Supervising per-database registries and PubSub
    * Starting core database processes:
      * `Fact.EventPublisher` – broadcasts new events to subscribers
      * `Fact.Database` – handles indexing, reads, and writes
      * `Fact.EventLedger` – manages ledger commits and event ordering
      * Indexers (`Fact.EventStreamIndexer`, `Fact.EventTagsIndexer`, `Fact.EventTypeIndexer`, etc.)
    * Supervising a dynamic supervisor for stream writers (`Fact.EventStreamWriterSupervisor`)

  Each child process is registered under a database-specific name via `Fact.Registry`,
  ensuring isolation between multiple database instances.

  This supervisor is automatically started by `Fact.Supervisor` when a database is initialized,
  and consumers typically interact with the database through higher-level APIs
  rather than directly starting this supervisor.
  """
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
