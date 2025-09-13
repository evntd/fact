defmodule Fact.Application do
  use Application

  def start(_type, _args) do
    
    {:ok, _} = :pg.start_link()

    children = [
      Fact.EventWriter,
      {Registry, keys: :unique, name: Fact.EventIndexerRegistry},
      Fact.EventIndexerManager
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Fact.Supervisor)
  end
end
