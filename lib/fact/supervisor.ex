defmodule Fact.Supervisor do
  @moduledoc """
  Top-level supervisor for the Fact runtime.

  `Fact.Supervisor` is the root of the supervision tree and is responsible for
  bootstrapping and supervising database instances. It coordinates database
  startup through `Fact.Bootstrapper` processes and supervises the resulting
  database processes for the lifetime of the system.

  At application startup, any database paths provided via the `:databases`
  option are bootstrapped automatically. Additional databases may be started
  at runtime with `start_database/1`, which bootstraps a database from the
  given path and returns its database identifier on success.

  This supervisor also owns the global `Fact.Registry`, which is used for
  process and `Fact.Context` lookup across the system.
  """
  use Supervisor

  require Logger

  def start_database(path) when is_binary(path) do
    with {:ok, _pid} <-
           Supervisor.start_child(__MODULE__, {Fact.Bootstrapper, [path: path, caller: self()]}) do
      receive do
        {:database_started, database_id} ->
          {:ok, database_id}

        {:database_locked, lock_info} ->
          {:error, :database_locked, lock_info}
      after
        3_000 ->
          {:error, :database_failure}
      end
    end
  end

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

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
