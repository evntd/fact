defmodule FactServer.Application do
  @moduledoc """
  Starts the Fact gRPC server and opens a configured database.

  Configure via application environment:

      config :fact, :fact_server,
        port: 50051,
        database: {"path/to/db", cache: [max_size: 64 * 1024 * 1024]}

  The `database` value can also be a plain path string with no options.
  When `database` is `nil` (e.g. in test environments), only `Fact.Supervisor`
  is started; the gRPC server and database open are skipped.
  """
  use Application

  @default_port 50051

  def start(_type, _args) do
    config = Application.get_env(:fact, :fact_server, [])

    case Keyword.get(config, :database) do
      nil ->
        Supervisor.start_link(
          [{Fact.Supervisor, []}],
          strategy: :one_for_one,
          name: FactServer.Supervisor
        )

      database ->
        port = Keyword.get(config, :port, @default_port)
        {path, db_opts} = normalize_database(database)
        database_name = Path.basename(path)

        children = [
          {Fact.Supervisor, [databases: [{path, db_opts}]]},
          {GRPC.Server.Supervisor, endpoint: FactServer.Endpoint, port: port, start_server: true}
        ]

        {:ok, sup} =
          Supervisor.start_link(children, strategy: :one_for_one, name: FactServer.Supervisor)

        {:ok, _} = Fact.when_ready(database_name, [])

        receive do
          {:database_ready, %{database_id: database_id}} ->
            :persistent_term.put({FactServer, :database_id}, database_id)
        end

        {:ok, sup}
    end
  end

  defp normalize_database({path, opts}), do: {path, opts}
  defp normalize_database(path) when is_binary(path), do: {path, []}
end
