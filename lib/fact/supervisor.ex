defmodule Fact.Supervisor do
  use Supervisor

  require Logger

  @doc """
  Get the `Fact.Context` for a running database by it `:database_id` or `:database_name`.
  """
  def get_context(id_or_name) when is_binary(id_or_name) do
    case Registry.lookup(Fact.Registry, id_or_name) do
      [{_pid, context}] ->
        {:ok, context}

      [] ->
        {:error, :not_found}
    end
  end

  def start_database(path) when is_binary(path) do
    with {:ok, _pid} <-
           Supervisor.start_child(__MODULE__, {Fact.Bootstrapper, [path: path, caller: self()]}) do
      receive do
        {:database_started, context} ->
          {:ok, context}
      after
        3_000 ->
          {:error, :database_failure}
      end
    end
  end

  def start_database(%Fact.Context{} = context) do
    Supervisor.start_child(__MODULE__, {Fact.DatabaseSupervisor, [context: context]})
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
