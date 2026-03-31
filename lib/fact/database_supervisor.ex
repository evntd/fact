defmodule Fact.DatabaseSupervisor do
  @moduledoc """
  Supervises all processes for a single Fact database instance.

  `Fact.DatabaseSupervisor` is the top-level supervisor for a database, responsible for:

    * Registering the database in `Fact.Registry`
    * Supervising per-database registries and PubSub
    * Starting core database processes.
    * Starting indexers.

  Each child process is registered under a database-specific name via `Fact.Registry`,
  ensuring isolation between multiple database instances.

  This supervisor is automatically started by `Fact.Supervisor` when a database is initialized, and consumers 
  typically interact with the database through higher-level APIs rather than directly starting this supervisor.
  """
  use Supervisor

  @typedoc """
  Options used when starting a `Fact.DatabaseSupervisor`.

  * `:context` - (required) The `Fact.Context` providing database identity and configuration needed to scope
    and register all supervised processes.
  * `:wal` - (optional) A keyword list of write-ahead log options forwarded to `Fact.WriteAheadLog`.
  """
  @typedoc since: "0.3.0"
  @type option ::
          {:context, Fact.Context.t()}
          | {:wal, [Fact.WriteAheadLog.wal_option()]}

  @doc """
  Returns a specification to start this module under a supervisor.

  The child spec is keyed by `t:Fact.database_id/0`, allowing multiple database instances to be supervised concurrently.

  Requires the `:context` option to be specified. Optionally accepts `:wal` options that are
  forwarded to `Fact.WriteAheadLog`.
  """
  @doc since: "0.3.0"
  @spec child_spec([option]) :: Supervisor.child_spec()
  def child_spec(opts) do
    context = Keyword.fetch!(opts, :context)
    wal = Keyword.get(opts, :wal, [])

    %{
      id: {__MODULE__, context.database_id},
      start: {__MODULE__, :start_link, [[context: context, wal: wal]]},
      type: :supervisor
    }
  end

  @doc """
  Starts a `Fact.DatabaseSupervisor`.

  This supervisor defines the runtime boundary for a single Fact database instance.
  It is registered under a database-scoped name via `Fact.Registry`, ensuring full isolation between
  multiple database instances running in the same VM.

  At startup, this supervisor initializes all database-scope infrastructure, including registries, PubSub,
  core write coordination processes, and event indexers.

  This function is typically invoked by `Fact.Supervisor` as part of database initialization and is not
  intended to be called directly by application code.
  """
  @doc since: "0.3.0"
  @spec start_link([option()]) :: Supervisor.on_start()
  def start_link(opts) do
    context = Keyword.fetch!(opts, :context)
    wal = Keyword.get(opts, :wal, [])
    %Fact.Context{database_id: database_id} = context

    Supervisor.start_link(__MODULE__, {context, wal}, name: Fact.Registry.supervisor(database_id))
  end

  @doc false
  @impl true
  def init({%Fact.Context{database_id: database_id} = context, wal}) do
    Fact.Registry.register(context)

    wal_opts =
      [database_id: database_id, name: Fact.Registry.via(database_id, Fact.WriteAheadLog)] ++ wal

    children = [
      {Registry, keys: :unique, name: Fact.Registry.registry(database_id)},
      {Phoenix.PubSub, name: Fact.Registry.pubsub(database_id)},
      {Fact.EventPublisher,
       database_id: database_id, name: Fact.Registry.via(database_id, Fact.EventPublisher)},
      {Fact.Database,
       database_id: database_id, name: Fact.Registry.via(database_id, Fact.Database)},
      {Fact.WriteAheadLog, wal_opts},
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
