defmodule FactServer.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/evntd/fact"

  def project do
    [
      app: :fact_server,
      version: @version,
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      source_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {FactServer.Application, []}
    ]
  end

  defp deps do
    [
      {:fact, in_umbrella: true},
      {:grpc, "~> 0.11.5"},
      {:protobuf, "~> 0.16.0"},
      {:jason, "~> 1.4"}
    ]
  end
end
