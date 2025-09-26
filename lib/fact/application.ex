defmodule Fact.Application do
  use Application

  def start(_type, _args) do
    {:ok, _} = :pg.start_link()
    
    Fact.Storage.init!()

    children = [
      {Registry, keys: :unique, name: Fact.EventLedgerRegistry},
      {Registry, keys: :unique, name: Fact.EventStreamRegistry},
      {Registry, keys: :unique, name: Fact.EventIndexerRegistry},
      Fact.EventLedger,
      Fact.EventIndexerManager,
      {DynamicSupervisor, strategy: :one_for_one, name: Fact.EventStreamWriterSupervisor}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Fact.Supervisor)
  end
end
