defmodule Fact.Supervisor do
  @moduledoc """
  Top-level supervisor for the Fact database system.
    
  `Fact.Supervisor` is the root of the supervision tree and is responsible for
  starting and supervising all database instances for the lifetime of the system.
    
  This module is responsible for:
    
    * Owning the Fact supervision tree
    * Managing database lifecycle and supervision
    * Coordinating database startup through `Fact.Bootstrapper`.

  It does not expose database APIs or persistence operations; it is concerned solely with system
  structure and process lifecycle.
  """
  @moduledoc since: "0.1.0"
  use Supervisor

  require Logger

  @typedoc """
  Option values used by the `start_link/1` function.

  * `{:databases, paths}` - A list of file-system paths identifying databases that should be bootstrapped automatically
    at startup.
  """
  @typedoc since: "0.1.0"
  @type option ::
          {:databases, list(Path.t())}

  @doc """
  Starts a database at the given filesystem path.
    
  This function delegates startup to a `Fact.Bootstrapper` process under this supervisor and waits
  for a startup acknowledgement message.
    
  The caller will block until one the following occurs:

    * The database is successfully started and the database identifier is returned
    * The database is already locked by another process
    * An error occurs during initialization.
    * The startup process times out.
      
  ### Process interaction
    
  The bootstrapper is started as a supervised child and is expected to send of the following
  messages back to the calling process:
    
    * `{:database_started, database_id}`
    * `{:database_locked, lock_metadata}`
    * `{:database_error, reason}`

  If no message is received within 3 seconds, the call fails with `{:error, :database_failure}`
  """
  @doc since: "0.1.0"
  @spec start_database(Path.t(), timeout()) ::
          {:ok, Fact.database_id()}
          | {:error, :database_locked, Fact.Lock.metadata_record()}
          | {:error, :database_failure}
          | {:error, term()}
  def start_database(path) when is_binary(path) do
    with {:ok, _pid} <-
           Supervisor.start_child(__MODULE__, {Fact.Bootstrapper, [path: path, caller: self()]}) do
      receive do
        {:database_started, database_id} ->
          {:ok, database_id}

        {:database_locked, lock_info} ->
          {:error, :database_locked, lock_info}

        {:database_error, reason} ->
          {:error, reason}
      after
        3_000 ->
          {:error, :database_failure}
      end
    end
  end

  @doc """
  Starts the `Fact.Supervisor`.
    
  At startup, the supervisor:
    
    * Starts the global `Fact.Registry`, used for process and `Fact.Context` lookup across the system.
    * Bootstraps any databases specified via the `:databases` option by starting a `Fact.Bootstrapper` process
      for each configured path.

  Databases listed in the `:databases` option are started eagerly as part of supervisor initialization. 
  Additional databases may be started later at runtime using `start_database/1`.
  """
  @doc since: "0.1.0"
  @spec start_link([option()]) :: Supervisor.on_start()
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc false
  @impl true
  def init(opts) do
    databases = Keyword.get(opts, :databases, [])

    children = [
      {Registry, keys: :unique, name: Fact.Registry}
    ]

    bootstrappers = Enum.map(databases, &{Fact.Bootstrapper, [path: &1]})
    Supervisor.init(children ++ bootstrappers, strategy: :one_for_one)
  end
end
