defmodule Fact.SystemSupervisor do
  use Supervisor

  require Logger

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    databases = Keyword.get(opts, :databases, [])
    children = Enum.map(databases, & {Fact.Bootstrapper, [path: &1]})
    Supervisor.init(children, strategy: :one_for_one)
  end

  def start_database(path) when is_binary(path) do
    with {:ok, _pid} <- Supervisor.start_child(__MODULE__, {Fact.Bootstrapper, [path: path, caller: self()]}) do
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
end
