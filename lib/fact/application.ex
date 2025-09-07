defmodule Fact.Application do
  use Application

  require Logger

  def start(_type, _args) do
    data_dir = Application.get_env(:fact, :data_directory, "./.fact")

    path_opts = init_directories!(data_dir)

    {:ok, _} = :pg.start_link()

    children = [
      {Fact.EventWriter, path_opts},
      {Fact.EventReader, path_opts},

      # Always-on indexers
      {Fact.EventTypeIndexer, [index_dir: Keyword.fetch!(path_opts, :event_type_index_dir)] },
      {Fact.EventStreamIndexer, [index_dir: Keyword.fetch!(path_opts, :event_stream_index_dir)]},

      # User-defined indexers
      {Registry, keys: :unique, name: Fact.DataKeyIndexerRegistry},
      {Fact.DataKeyIndexerManager, [index_dir: Keyword.fetch!(path_opts, :data_key_index_dir)]}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Fact.Supervisor)
  end

  defp init_directories!(data_dir) do
    dirs = [
      data_dir: data_dir,
      events_dir: Path.join(data_dir, "events"),
      indices_dir: Path.join(data_dir, "indices"),
      event_type_index_dir: Path.join(data_dir, "indices/type"),
      event_stream_index_dir: Path.join(data_dir, "indices/stream"),
      data_key_index_dir: Path.join(data_dir, "indices/data")
    ]

    dirs |> Enum.each(fn {_k,path} ->
      unless File.exists?(path) do
        File.mkdir_p!(path)
        Logger.debug("created: #{path}")
      end
    end)

    files = [
      append_log: Path.join(data_dir, "events/.log")
    ]

    files |> Enum.each(fn {_key, path} ->
      unless File.exists?(path) do
        File.write!(path, "")
        Logger.debug("created: #{path}")
      end
    end)

    Keyword.merge(dirs, files)

  end

end
