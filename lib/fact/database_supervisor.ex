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
  Runtime options for database subsystems, passed via the `:opts` key.

    * `:cache` - Record cache options. See `t:Fact.RecordCache.cache_option/0`.
    * `:merkle` - Merkle Mountain Range options. See `t:Fact.MerkleMountainRange.merkle_option/0`.
      Requires CAS mode. May also be the bare atom `:merkle` to enable with defaults.
    * `:wal` - Write-ahead log options. See `t:Fact.WriteAheadLog.wal_option/0`.
  """
  @typedoc since: "0.3.0"
  @type subsystem_option ::
          {:cache, [Fact.RecordCache.cache_option()]}
          | {:merkle, [Fact.MerkleMountainRange.merkle_option()]}
          | {:wal, [Fact.WriteAheadLog.wal_option()]}

  @typedoc """
  Options used when starting a `Fact.DatabaseSupervisor`.

    * `:context` - (required) The `Fact.Context` providing database identity and configuration.
    * `:opts` - (optional) Runtime options for database subsystems. See `t:subsystem_option/0`.
  """
  @typedoc since: "0.3.0"
  @type option ::
          {:context, Fact.Context.t()}
          | {:opts, [subsystem_option()]}

  @doc """
  Returns a specification to start this module under a supervisor.

  The child spec is keyed by `t:Fact.database_id/0`, allowing multiple database instances to be supervised concurrently.

  Requires the `:context` option to be specified. Optionally accepts `:opts` for database
  subsystem configuration. See `t:subsystem_option/0`.
  """
  @doc since: "0.3.0"
  @spec child_spec([option]) :: Supervisor.child_spec()
  def child_spec(init_opts) do
    context = Keyword.fetch!(init_opts, :context)
    opts = Keyword.get(init_opts, :opts, [])

    %{
      id: {__MODULE__, context.database_id},
      start: {__MODULE__, :start_link, [[context: context, opts: opts]]},
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
    runtime_opts = Keyword.get(opts, :opts, [])
    %Fact.Context{database_id: database_id} = context

    Supervisor.start_link(__MODULE__, {context, runtime_opts},
      name: Fact.Registry.supervisor(database_id)
    )
  end

  @doc false
  @impl true
  def init({%Fact.Context{database_id: database_id} = context, opts}) do
    Fact.Registry.register(context)

    encryption_opts = Keyword.get(opts, :encryption, [])
    encrypted = Keyword.get(encryption_opts, :wrapped_dek) != nil

    wal_opts =
      [
        database_id: database_id,
        name: Fact.Registry.via(database_id, Fact.WriteAheadLog),
        encrypted: encrypted
      ] ++
        Keyword.get(opts, :wal, [])

    cache_opts = Keyword.get(opts, :cache, [])
    key_ring_children = key_ring_children(database_id, opts)

    children =
      [
        {Registry, keys: :unique, name: Fact.Registry.registry(database_id)}
      ] ++
        key_ring_children ++
        [
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
           database_id: database_id,
           name: Fact.Registry.via(database_id, Fact.EventStreamsIndexer)},
          {Fact.EventStreamsByCategoryIndexer,
           database_id: database_id,
           name: Fact.Registry.via(database_id, Fact.EventStreamsByCategoryIndexer)},
          {DynamicSupervisor,
           strategy: :one_for_one,
           name: Fact.Registry.via(database_id, Fact.EventStreamWriterSupervisor)}
        ]

    cache_children =
      case Keyword.get(cache_opts, :max_size) do
        max_size when is_integer(max_size) and max_size > 0 ->
          cache_child_opts =
            [
              database_id: database_id,
              max_size: max_size,
              name: Fact.Registry.via(database_id, Fact.RecordCache)
            ] ++ Keyword.take(cache_opts, [:decay_interval])

          [{Fact.RecordCache, cache_child_opts}]

        _ ->
          []
      end

    merkle_children = merkle_children(context, database_id, opts)

    Supervisor.init(children ++ cache_children ++ merkle_children, strategy: :one_for_one)
  end

  defp key_ring_children(database_id, opts) do
    encryption_opts = Keyword.get(opts, :encryption, [])

    case Keyword.get(encryption_opts, :wrapped_dek) do
      nil ->
        []

      wrapped_dek ->
        kek = Keyword.fetch!(encryption_opts, :kek)

        [
          {Fact.KeyRing,
           database_id: database_id,
           wrapped_dek: wrapped_dek,
           kek: kek,
           name: Fact.Registry.via(database_id, Fact.KeyRing)}
        ]
    end
  end

  defp merkle_children(context, database_id, opts) do
    merkle_opts = merkle_opts(opts)

    if merkle_opts != nil and cas_mode?(context) do
      child_opts =
        [
          database_id: database_id,
          name: Fact.Registry.via(database_id, Fact.MerkleMountainRange)
        ] ++ merkle_opts

      [{Fact.MerkleMountainRange, child_opts}]
    else
      []
    end
  end

  defp merkle_opts(opts) do
    cond do
      :merkle in opts -> []
      Keyword.has_key?(opts, :merkle) -> Keyword.get(opts, :merkle)
      true -> nil
    end
  end

  defp cas_mode?(%Fact.Context{record_file_name: %{module: mod}}) do
    mod.family() == :hash
  end
end
