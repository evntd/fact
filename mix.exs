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
      docs: docs(),
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
      {:uuid, "~> 1.1.8"},

      # Tools
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "Fact",
      authors: ["Jake Bruun"]
    ]
  end
end
