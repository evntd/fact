defmodule Fact.Application do
  use Application
  alias Fact.Paths
  require Logger

  def start(_type, _args) do
    
    init_directories!()

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

  defp init_directories!() do
    
    File.mkdir_p!(Paths.events)
    unless File.exists?(Paths.append_log), do: File.write!(Paths.append_log, "")
    
    File.mkdir_p!(Paths.index(:event_type))
    File.mkdir_p!(Paths.index(:event_stream))
    
  end

end
