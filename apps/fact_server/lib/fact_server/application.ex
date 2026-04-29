defmodule FactServer.Application do
  @moduledoc """
  Starts the Fact gRPC server and opens configured databases.

  Add to your supervision tree:

      children = [
        FactServer.Application
      ]

  Or configure via application environment:

      config :fact, :fact_server,
        port: 50051,
        databases: [
          %{path: "/data/my_db"},
          %{path: "/data/other_db", opts: [cache: [max_size: 1000]]}
        ]
  """
  use Application

  @default_port 50051

  def start(_type, _args) do
    config = Application.get_env(:fact, :fact_server, [])
    port = Keyword.get(config, :port, @default_port)
    databases = Keyword.get(config, :databases, [])

    Enum.each(databases, fn %{path: path} = db ->
      {:ok, _} = Fact.open(path, Map.get(db, :opts, []))
    end)

    children = [
      {GRPC.Server.Supervisor, endpoint: FactServer.Endpoint, port: port, start_server: true}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: FactServer.Supervisor)
  end
end
