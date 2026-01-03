defmodule Fact.SystemSupervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    databases = Keyword.get(opts, :databases, [])
    children = Enum.map(databases, &bootstrapper_child_spec/1)
    Supervisor.init(children, strategy: :one_for_one)
  end

  def start_database(path) when is_binary(path) do
    {:ok, _pid} = Supervisor.start_child(__MODULE__, bootstrapper_child_spec(path))

    receive do
      {:database_started, context} ->
        {:ok, context}
    end
  end

  def start_database(%Fact.Context{} = context) do
    Supervisor.start_child(__MODULE__, database_supervisor_child_spec(context))
  end

  defp bootstrapper_child_spec(path) do
    Supervisor.child_spec({Fact.Bootstrapper, [path: path, caller: self()]},
      id: {Fact.Bootstrapper, path},
      restart: :temporary
    )
  end

  defp database_supervisor_child_spec(%Fact.Context{database_id: database_id} = context) do
    Supervisor.child_spec({Fact.DatabaseSupervisor, context: context},
      id: {Fact.DatabaseSupervisor, database_id},
      type: :supervisor
    )
  end
end
