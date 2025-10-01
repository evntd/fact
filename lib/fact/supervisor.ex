defmodule Fact.Supervisor do
  @moduledoc false
  use Supervisor
  import Fact.Names
  require Logger

  @default :""

  def start_link(opts) do
    name = Keyword.get(opts, :name, @default)
    Supervisor.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(opts) do
    instance = Keyword.fetch!(opts, :name)
    path = Keyword.get(opts, :path, Path.join(".fact", normalize(instance)))
    driver = Keyword.get(opts, :driver, Fact.Storage.Driver.ByEventId)
    format = Keyword.get(opts, :format, Fact.Storage.Format.Json)
    indexers = Keyword.get(opts, :indexers, default_indexers(instance, path))

    events_path = Path.join(path, "events")
    ledger_path = Path.join(path, "ledger")

    children = [
      {Registry, keys: :unique, name: registry(instance)},
      {Registry, keys: :unique, name: event_stream_registry(instance)},
      {Registry, keys: :unique, name: event_indexer_registry(instance)},
      {Fact.EventPublisher, []},
      {Fact.Storage,
       [
         instance: instance,
         events: events_path,
         ledger: ledger_path,
         driver: driver,
         format: format
       ]},
      {Fact.EventLedger, [instance: instance]},
      {Fact.EventIndexerManager, [instance: instance, indexers: indexers]},
      {DynamicSupervisor,
       strategy: :one_for_one, name: via(instance, Fact.EventStreamWriterSupervisor)}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp default_indexers(instance, path) do
    default_opts = [instance: instance, path: Path.join(path, "indices")]

    [
      {Fact.EventStreamIndexer, default_opts},
      {Fact.EventTypeIndexer, default_opts},
      {Fact.EventTagsIndexer, default_opts},
      {Fact.EventDataIndexer, default_opts ++ [encoding: {:hash, :sha}, enabled: false]},
      {Fact.EventStreamCategoryIndexer, default_opts ++ [enabled: false]},
      {Fact.EventStreamsIndexer, default_opts ++ [enabled: false]}
    ]
  end

  defp normalize(name) do
    to_string(name)
    |> String.replace_prefix("Elixir.", "")
    |> String.replace("/", "_")
    |> String.downcase()
  end
end
