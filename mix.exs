defmodule Fact.MixProject do
  use Mix.Project

  @name "Fact"
  @version "0.0.1"
  @source_url "https://github.com/evntd/fact"

  def project do
    [
      app: :fact,
      version: @version,
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      docs: docs(),
      package: package(),
      name: @name,
      source_url: @source_url,
      test_coverage: test_coverage()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:uuid, "~> 2.0", hex: :uuid_erl},

      # Tools
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp description do
    """
    A file system based event store.
    """
  end

  defp docs do
    [
      main: "Fact",
      canonical: "https://hexdocs.pm/Fact"
    ]
  end

  defp package do
    [
      maintainers: ["Jake Bruun"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url
      }
    ]
  end

  defp test_coverage do
    [
      ignore_modules: [
        Fact.EventIndexer,
        Fact.IndexFileReader.Backwards.Chunked
      ],
      summary: [
        threshold: 80
      ]
    ]
  end
end
