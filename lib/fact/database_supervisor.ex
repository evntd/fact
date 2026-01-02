defmodule Fact.DatabaseSupervisor do
  use Supervisor

  def start_link(context: context) do
    %Fact.Context{database_id: database_id} = context

    Supervisor.start_link(__MODULE__, context,
      name: Module.concat(Fact.DatabaseSupervisor, database_id)
    )
  end

  @impl true
  def init(%Fact.Context{} = _context) do
    children = []
    Supervisor.init(children, strategy: :one_for_one)
  end
end
