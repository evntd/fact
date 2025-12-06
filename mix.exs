defmodule Fact.MixProject do
  use Mix.Project

  @version "0.0.1"

  def project do
    [
      app: :fact,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      docs: docs(),
      package: package(),
      name: "Fact",
      source_url: "https://github.com/evntd/fact"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:uuid, "~> 2.0", hex: :uuid_erl},

      # Tools
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end
  
  defp description do
    """
    A file system based event sourcing database for maximum portability.
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
        "GitHub" => "https://github.com/evntd/fact"
      }
    ]
  end
end
