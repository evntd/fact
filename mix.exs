defmodule Fact.MixProject do
  use Mix.Project

  @name "Fact"
  @version "0.0.1"
  @codename "Hatchling"
  @source_url "https://github.com/evntd/fact"
  @maintainers ["Jake Bruun"]
  @authors ["Jake Bruun"]

  def project do
    [
      app: :fact,
      version: @version,
      codename: @codename,
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
      {:jason, "~> 1.4", optional: true},
      {:phoenix_pubsub, "~> 2.2"},
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
      api_references: true,
      authors: @authors,
      canonical: "https://hexdocs.pm/Fact",
      cover: "guides/assets/images/epub-cover.png",
      extra_section: "GUIDES",
      extras: [
        "guides/introduction/overview.md",
        "LICENSE"
      ],
      favicon: "guides/assets/images/turt-16.png",
      groups_for_extras: [
        Introduction: [
          "guides/introduction/overview.md"
        ]
      ],
      groups_for_modules: [
        Api: [
          Fact,
          Fact.Instance,
          Fact.Types
        ],
        Core: [
          Fact.EventLedger,
          Fact.EventReader,
          Fact.EventStreamWriter,
          Fact.Query,
          Fact.QueryItem
        ],
        Indexing: [
          Fact.EventDataIndexer,
          Fact.EventIndexer,
          Fact.EventIndexerManager,
          Fact.EventStreamCategoryIndexer,
          Fact.EventStreamIndexer,
          Fact.EventStreamsByCategoryIndexer,
          Fact.EventStreamsIndexer,
          Fact.EventTagsIndexer,
          Fact.EventTypeIndexer,
          Fact.IndexFileReader.Backwards.Line,
          Fact.IndexFileReader.Backwards.Chunked
        ],
        Process: [
          Fact.Lock,
          Fact.LockOwner,
          Fact.Supervisor
        ],
        "Pub/Sub": [
          Fact.CatchUpSubscription,
          Fact.EventPublisher
        ],
        Storage: [
          Fact.Storage,
          Fact.Storage.Driver,
          Fact.Storage.Driver.ByEventId,
          Fact.Storage.Driver.ContentAddressable,
          Fact.Storage.Format,
          Fact.Storage.Format.Json,
          Fact.Storage.Manifest
        ]
      ],
      language: "en",
      logo: "guides/assets/images/turt-48.png",
      main: "overview",
      nest_modules_by_prefix: [
        Fact.IndexFileReader
      ]
    ]
  end

  defp package do
    [
      maintainers: @maintainers,
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url
      }
    ]
  end

  defp test_coverage do
    [
      ignore_modules: [
        Fact.EventIndexer
      ],
      summary: [
        threshold: 80
      ]
    ]
  end
end
