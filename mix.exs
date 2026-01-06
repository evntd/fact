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
          Fact.Types
        ],
        Context: [
          Fact.Context,
          Fact.Event,
          Fact.Event.Id,
          Fact.Event.Schema,
          Fact.IndexCheckpointFile,
          Fact.IndexCheckpointFile.Decoder,
          Fact.IndexCheckpointFile.Encoder,
          Fact.IndexCheckpointFile.Name,
          Fact.IndexCheckpointFile.Reader,
          Fact.IndexCheckpointFile.Writer,
          Fact.IndexFile,
          Fact.IndexFile.Decoder,
          Fact.IndexFile.Encoder,
          Fact.IndexFile.Name,
          Fact.IndexFile.Reader,
          Fact.IndexFile.Writer,
          Fact.LedgerFile,
          Fact.LedgerFile.Decoder,
          Fact.LedgerFile.Encoder,
          Fact.LedgerFile.Name,
          Fact.LedgerFile.Reader,
          Fact.LedgerFile.Writer,
          Fact.LockFile,
          Fact.LockFile.Decoder,
          Fact.LockFile.Encoder,
          Fact.LockFile.Name,
          Fact.LockFile.Reader,
          Fact.LockFile.Writer,
          Fact.RecordFile,
          Fact.RecordFile.Decoder,
          Fact.RecordFile.Encoder,
          Fact.RecordFile.Name,
          Fact.RecordFile.Reader,
          Fact.RecordFile.Writer,
          Fact.Registry,
          Fact.Storage
        ],
        Core: [
          Fact.Database,
          Fact.EventLedger,
          Fact.EventReader,
          Fact.EventStreamWriter,
          Fact.Query,
          Fact.QueryItem
        ],
        Genesis: [
          Fact.Genesis,
          Fact.Genesis.Command.CreateDatabase.V1,
          Fact.Genesis.Creator,
          Fact.Genesis.Decider,
          Fact.Genesis.Event.DatabaseCreated.V1
        ],
        Indexing: [
          Fact.EventDataIndexer,
          Fact.EventIndexer,
          Fact.EventStreamCategoryIndexer,
          Fact.EventStreamIndexer,
          Fact.EventStreamsByCategoryIndexer,
          Fact.EventStreamsIndexer,
          Fact.EventTagsIndexer,
          Fact.EventTypeIndexer
        ],
        Process: [
          Fact.Bootstrapper,
          Fact.DatabaseSupervisor,
          Fact.Lock,
          Fact.Supervisor
        ],
        "Pub/Sub": [
          Fact.CatchUpSubscription,
          Fact.CatchUpSubscription.All,
          Fact.CatchUpSubscription.Index,
          Fact.CatchUpSubscription.Query,
          Fact.CatchUpSubscription.Stream,
          Fact.EventPublisher
        ],
        Seams: [
          Fact.Seam,
          Fact.Seam.Adapter,
          Fact.Seam.Decoder,
          Fact.Seam.Decoder.Adapter,
          Fact.Seam.Decoder.Delimited.V1,
          Fact.Seam.Decoder.Integer.V1,
          Fact.Seam.Decoder.Json.V1,
          Fact.Seam.Decoder.Raw.V1,
          Fact.Seam.Decoder.Registry,
          Fact.Seam.Encoder,
          Fact.Seam.Encoder.Adapter,
          Fact.Seam.Encoder.Delimited.V1,
          Fact.Seam.Encoder.Integer.V1,
          Fact.Seam.Encoder.Json.V1,
          Fact.Seam.Encoder.Raw.V1,
          Fact.Seam.Encoder.Registry,
          Fact.Seam.EventId,
          Fact.Seam.EventId.Adapter,
          Fact.Seam.EventId.Registry,
          Fact.Seam.EventId.Uuid.V4,
          Fact.Seam.EventSchema,
          Fact.Seam.EventSchema.Adapter,
          Fact.Seam.EventSchema.Registry,
          Fact.Seam.EventSchema.Standard.V1,
          Fact.Seam.FileName,
          Fact.Seam.FileName.Adapter,
          Fact.Seam.FileName.ContentAddressable.V1,
          Fact.Seam.FileName.EventId.V1,
          Fact.Seam.FileName.Fixed.V1,
          Fact.Seam.FileName.Hash.V1,
          Fact.Seam.FileName.Raw.V1,
          Fact.Seam.FileName.Registry,
          Fact.Seam.FileReader,
          Fact.Seam.FileReader.Adapter,
          Fact.Seam.FileReader.FixedLength.V1,
          Fact.Seam.FileReader.Full.V1,
          Fact.Seam.FileReader.Registry,
          Fact.Seam.FileWriter,
          Fact.Seam.FileWriter.Adapter,
          Fact.Seam.FileWriter.Standard.V1,
          Fact.Seam.FileWriter.Registry,
          Fact.Seam.Instance,
          Fact.Seam.Parsers,
          Fact.Seam.Registry,
          Fact.Seam.Storage,
          Fact.Seam.Storage.Adapter,
          Fact.Seam.Storage.Standard.V1,
          Fact.Seam.Storage.Registry
        ]
      ],
      language: "en",
      logo: "guides/assets/images/turt-48.png",
      main: "overview",
      nest_modules_by_prefix: [
        Fact.IndexCheckpointFile,
        Fact.IndexFile,
        Fact.LedgerFile,
        Fact.RecordFile,
        Fact.Seam,
        Fact.Seam.Decoder,
        Fact.Seam.Encoder,
        Fact.Seam.EventId,
        Fact.Seam.EventSchema,
        Fact.Seam.FileName,
        Fact.Seam.FileReader,
        Fact.Seam.FileWriter,
        Fact.Seam.Storage
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
