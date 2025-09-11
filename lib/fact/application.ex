defmodule Fact.Application do
  use Application

  def start(_type, _args) do
    
    {:ok, _} = :pg.start_link()

    children = [
      Fact.EventWriter,
      Fact.EventReader,

      # Always-on indexers
      Fact.EventTypeIndexer,
      Fact.EventStreamIndexer,

      # User-defined indexers
      {Registry, keys: :unique, name: Fact.EventDataIndexerRegistry},
      Fact.EventDataIndexerManager
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Fact.Supervisor)
  end
end
