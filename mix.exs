defmodule Fact.MixProject do
  use Mix.Project

  @name "Fact"
  @version "0.0.1-alpha.1"
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
      dialyzer: dialyzer(),
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
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
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
        "guides/versions/whats-up-with-all-these-versions.md",
        "LICENSE"
      ],
      favicon: "guides/assets/images/turt-16.png",
      groups_for_extras: [
        Introduction: [
          "guides/introduction/overview.md"
        ],
        Versions: [
          "guides/versions/whats-up-with-all-these-versions.md"
        ]
      ],
      groups_for_modules: [
        Api: [
          Fact,
          Fact.Instance,
          Fact.Types
        ],
        Bootstrapping: [
          Fact.Genesis
        ],
        Context: [
          Fact.Context,
          Fact.IndexCheckpointFileWriter,
          Fact.IndexFileContent,
          Fact.IndexFileName,
          Fact.IndexFileWriter,
          Fact.LedgerFileContent,
          Fact.LedgerFileWriter,
          Fact.RecordFileContent,
          Fact.RecordFileName,
          Fact.RecordFileWriter,
          Fact.RecordSchema,
          Fact.StorageLayout
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
          Fact.IndexFileReader.Line,
          Fact.IndexFileReader.Chunked
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
        Seams: [
          Fact.Seam,
          Fact.Seam.Adapter,
          Fact.Seam.FileContent,
          Fact.Seam.FileContent.Delimited.V1,
          Fact.Seam.FileContent.Json.V1,
          Fact.Seam.FileContent.Registry,
          Fact.Seam.FileName,
          Fact.Seam.FileName.ContentAddressable.V1,
          Fact.Seam.FileName.EventId.V1,
          Fact.Seam.FileName.Hash.V1,
          Fact.Seam.FileName.Raw.V1,
          Fact.Seam.FileName.Registry,
          Fact.Seam.FileReader,
          Fact.Seam.FileReader.Standard.V1,
          Fact.Seam.FileReader.Registry,
          Fact.Seam.FileWriter,
          Fact.Seam.FileWriter.Adapter,
          Fact.Seam.FileWriter.Standard.V1,
          Fact.Seam.FileWriter.Registry,
          Fact.Seam.Instance,
          Fact.Seam.RecordSchema,
          Fact.Seam.RecordSchema.Standard.V1,
          Fact.Seam.RecordSchema.Registry,
          Fact.Seam.Registry,
          Fact.Seam.StorageLayout,
          Fact.Seam.StorageLayout.Standard.V1,
          Fact.Seam.StorageLayout.Registry
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
        Fact.IndexFileFormat,
        Fact.IndexFileReader,
        Fact.IndexFilename,
        Fact.RecordFileFormat,
        Fact.RecordFilename,
        Fact.RecordSchema,
        Fact.Seam,
        Fact.Storage,
        Fact.StorageLayout
      ]
    ]
  end

  defp dialyzer do
    [
      plt_add_apps: [:ex_unit, :mix, :phoenix_pubsub]
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
