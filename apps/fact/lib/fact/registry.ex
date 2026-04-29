defmodule Fact.Registry do
  @moduledoc """
  Registry utilities for process discovery and naming within the Fact system.

  `Fact.Registry` provides two related layers of process registration:

    * the global `Fact.Registry`, which tracks running databases and exposes
      lookup helpers for resolving a database's `Fact.Context` by identifier or name
    * database-specific registries, one per database instance, which are used
      for naming and locating processes that belong to that database.

  The global registry stores:

    * the `Fact.Context` for a database under both its `:database_id` and
      `:database_name`, and
    * the `:database_id` under the `:database_name`.

  Helper functions such as `get_context/1` and `get_database_id/1` provide
  convenient access to this information.

  For database-local processes, this module exposes helpers like `registry/1`,
  `via/2`, and `lookup/2`, which construct or reference the appropriate
  database-specific `Registry` module for the given `database_id`. It also
  provides `pubsub/1` and `supervisor/1` to derive the corresponding PubSub
  and supervisor module names for that database.
  """
  @moduledoc since: "0.1.0"

  @doc """
  Get the `Fact.Context` for a running database by its `:database_id` or `:database_name`.
  """
  @doc since: "0.1.0"
  @spec get_context(Fact.database_id() | Fact.database_name()) ::
          {:ok, Fact.Context.t()} | {:error, :not_found}
  def get_context(id_or_name) when is_binary(id_or_name) do
    case Registry.lookup(__MODULE__, {:context, id_or_name}) do
      [{_pid, context}] ->
        {:ok, context}

      [] ->
        {:error, :not_found}
    end
  end

  @doc """
  Get the `:database_id` for a running database by its `:database_name`.
  """
  @doc since: "0.1.0"
  @spec get_database_id(Fact.database_name()) :: Fact.database_id()
  def get_database_id(name) when is_binary(name) do
    case Registry.lookup(__MODULE__, {:id, name}) do
      [{_pid, id}] ->
        {:ok, id}

      [] ->
        {:error, :not_found}
    end
  end

  @doc """
  Wrapper around `Registry.lookup/2` to simplify lookup of Fact database processes.
  """
  @doc since: "0.1.0"
  @spec lookup(Fact.database_id(), atom()) :: [{pid(), term()}]
  def lookup(database_id, key) do
    Registry.lookup(registry(database_id), key)
  end

  @doc """
  Gets the name of the PubSub process for the specified database.
  """
  @doc since: "0.1.0"
  @spec pubsub(Fact.database_id()) :: atom()
  def pubsub(database_id) when is_binary(database_id) do
    Module.concat(Fact.PubSub, database_id)
  end

  @doc """
  This registers the supplied `Fact.Context` with the `Fact.Registry` keyed by `t:Fact.database_id/0` 
  and `t:Fact.database_name/0`.
    
  This is an internal function used by `Fact.DatabaseSupervisor` when it is initialized. If the process
  terminates for any reason these registry entries will be automagically cleaned up.
  """
  @doc since: "0.1.0"
  def register(%Fact.Context{database_id: database_id, database_name: database_name} = context) do
    # Store the context by id and name within the registry for lookups when needed.
    Registry.register(__MODULE__, {:context, database_id}, context)
    Registry.register(__MODULE__, {:context, database_name}, context)
    # Store the id by name.
    Registry.register(__MODULE__, {:id, database_name}, database_id)
  end

  @doc """
  Gets the name of the Registry process for the specified database.
  """
  @doc since: "0.1.0"
  @spec registry(Fact.database_id()) :: atom()
  def registry(database_id) when is_binary(database_id) do
    Module.concat(Fact.Registry, database_id)
  end

  @doc """
  Gets the name of the Supervisor process for the specified database.
  """
  @doc since: "0.1.0"
  @spec supervisor(Fact.database_id()) :: atom()
  def supervisor(database_id) when is_binary(database_id) do
    Module.concat(Fact.DatabaseSupervisor, database_id)
  end

  @doc """
  Utility method to create Fact database specific `{:via, Registry, {registry, key}}` tuples.
  This is used extensively for process lookup for messaging within Fact.
  """
  @doc since: "0.1.0"
  @spec via(Fact.database_id(), atom()) :: {:via, Registry, {atom(), atom()}}
  def via(database_id, key) when is_binary(database_id) do
    {:via, Registry, {registry(database_id), key}}
  end
end
