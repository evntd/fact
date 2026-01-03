defmodule Fact.Context do
  alias Fact.EventId
  alias Fact.IndexCheckpointFile
  alias Fact.IndexFile
  alias Fact.LedgerFile
  alias Fact.LockFile
  alias Fact.RecordFile
  alias Fact.StorageLayout

  defstruct [
    # Identity
    :database_id,

    # Compatibility,
    :elixir_version,
    :erts_version,
    :fact_version,
    :otp_version,
    :os_version,

    # Seams
    :event_id,

    ## Index Checkpoints
    :index_checkpoint_file_decoder,
    :index_checkpoint_file_encoder,
    :index_checkpoint_file_name,
    :index_checkpoint_file_reader,
    :index_checkpoint_file_writer,

    ## Indexes
    :index_file_decoder,
    :index_file_encoder,
    :index_file_name,
    :index_file_reader,
    :index_file_writer,

    ## Ledger
    :ledger_file_decoder,
    :ledger_file_encoder,
    :ledger_file_name,
    :ledger_file_reader,
    :ledger_file_writer,

    ## Lock File
    :lock_file_decoder,
    :lock_file_encoder,
    :lock_file_name,
    :lock_file_reader,
    :lock_file_writer,

    ## Records
    :record_file_decoder,
    :record_file_encoder,
    :record_file_name,
    :record_file_reader,
    :record_file_writer,
    :record_file_schema,

    ## Storage Layout
    :storage_layout
  ]

  def init(path) do
    %__MODULE__{
      event_id: Fact.EventId.init(),
      index_checkpoint_file_decoder: IndexCheckpointFile.Decoder.init(),
      index_checkpoint_file_encoder: IndexCheckpointFile.Encoder.init(),
      index_checkpoint_file_name: IndexCheckpointFile.Name.init(),
      index_checkpoint_file_reader: IndexCheckpointFile.Reader.init(),
      index_checkpoint_file_writer: IndexCheckpointFile.Writer.init(),
      index_file_decoder: IndexFile.Decoder.init(),
      index_file_encoder: IndexFile.Encoder.init(),
      index_file_name: IndexFile.Name.init(),
      index_file_reader: IndexFile.Reader.init(%{length: 32, padding: 1}),
      index_file_writer: IndexFile.Writer.init(),
      ledger_file_decoder: LedgerFile.Decoder.init(),
      ledger_file_encoder: LedgerFile.Encoder.init(),
      ledger_file_name: LedgerFile.Name.init(),
      ledger_file_reader: LedgerFile.Reader.init(%{length: 32, padding: 1}),
      ledger_file_writer: LedgerFile.Writer.init(),
      lock_file_decoder: LockFile.Decoder.init(),
      lock_file_encoder: LockFile.Encoder.init(),
      lock_file_name: LockFile.Name.init(),
      lock_file_reader: LockFile.Reader.init(),
      lock_file_writer: LockFile.Writer.init(),
      record_file_decoder: RecordFile.Decoder.init(),
      record_file_encoder: RecordFile.Encoder.init(),
      record_file_name: RecordFile.Name.init(),
      record_file_reader: RecordFile.Reader.init(),
      record_file_writer: RecordFile.Writer.init(),
      record_file_schema: RecordFile.Schema.init(),
      storage_layout: StorageLayout.init(%{path: Path.absname(path)})
    }
  end

  def from_genesis(%Fact.Genesis.Event.DatabaseCreated.V1{} = event) do
    %__MODULE__{
      database_id: event.database_id,
      elixir_version: event.elixir_version,
      erts_version: event.erts_version,
      fact_version: event.fact_version,
      otp_version: event.otp_version,
      os_version: event.os_version,
      event_id: EventId.from_config(event.event_id),
      index_checkpoint_file_decoder:
        IndexCheckpointFile.Decoder.from_config(event.index_checkpoint_file_decoder),
      index_checkpoint_file_encoder:
        IndexCheckpointFile.Encoder.from_config(event.index_checkpoint_file_encoder),
      index_checkpoint_file_name:
        IndexCheckpointFile.Name.from_config(event.index_checkpoint_file_name),
      index_checkpoint_file_reader:
        IndexCheckpointFile.Reader.from_config(event.index_checkpoint_file_reader),
      index_checkpoint_file_writer:
        IndexCheckpointFile.Writer.from_config(event.index_checkpoint_file_writer),
      index_file_decoder: IndexFile.Decoder.from_config(event.index_file_decoder),
      index_file_encoder: IndexFile.Encoder.from_config(event.index_file_encoder),
      index_file_name: IndexFile.Name.from_config(event.index_file_name),
      index_file_reader: IndexFile.Reader.from_config(event.index_file_reader),
      index_file_writer: IndexFile.Writer.from_config(event.index_file_writer),
      ledger_file_decoder: LedgerFile.Decoder.from_config(event.ledger_file_decoder),
      ledger_file_encoder: LedgerFile.Encoder.from_config(event.ledger_file_encoder),
      ledger_file_name: LedgerFile.Name.from_config(event.ledger_file_name),
      ledger_file_reader: LedgerFile.Reader.from_config(event.ledger_file_reader),
      ledger_file_writer: LedgerFile.Writer.from_config(event.ledger_file_writer),
      lock_file_decoder: LockFile.Decoder.from_config(event.lock_file_decoder),
      lock_file_encoder: LockFile.Encoder.from_config(event.lock_file_encoder),
      lock_file_name: LockFile.Name.from_config(event.lock_file_name),
      lock_file_reader: LockFile.Reader.from_config(event.lock_file_reader),
      lock_file_writer: LockFile.Writer.from_config(event.lock_file_writer),
      record_file_decoder: RecordFile.Decoder.from_config(event.record_file_decoder),
      record_file_encoder: RecordFile.Encoder.from_config(event.record_file_encoder),
      record_file_name: RecordFile.Name.from_config(event.record_file_name),
      record_file_reader: RecordFile.Reader.from_config(event.record_file_reader),
      record_file_writer: RecordFile.Writer.from_config(event.record_file_writer),
      record_file_schema: RecordFile.Schema.from_config(event.record_file_schema),
      storage_layout: StorageLayout.from_config(event.storage_layout)
    }
  end

  def from_record(%{"event_type" => "Elixir.Fact.Genesis.Event.DatabaseCreated.V1"} = record) do
    event_data = Map.get(record, "event_data")

    %__MODULE__{
      database_id: Map.get(event_data, "database_id"),
      elixir_version: Map.get(event_data, "elixir_version"),
      erts_version: Map.get(event_data, "erts_version"),
      fact_version: Map.get(event_data, "fact_version"),
      otp_version: Map.get(event_data, "otp_version"),
      event_id: EventId.from_config(Map.get(event_data, "event_id")),
      index_checkpoint_file_decoder:
        IndexCheckpointFile.Decoder.from_config(
          Map.get(event_data, "index_checkpoint_file_decoder")
        ),
      index_checkpoint_file_encoder:
        IndexCheckpointFile.Encoder.from_config(
          Map.get(event_data, "index_checkpoint_file_encoder")
        ),
      index_checkpoint_file_name:
        IndexCheckpointFile.Name.from_config(Map.get(event_data, "index_checkpoint_file_name")),
      index_checkpoint_file_reader:
        IndexCheckpointFile.Reader.from_config(
          Map.get(event_data, "index_checkpoint_file_reader")
        ),
      index_checkpoint_file_writer:
        IndexCheckpointFile.Writer.from_config(
          Map.get(event_data, "index_checkpoint_file_writer")
        ),
      index_file_decoder:
        IndexFile.Decoder.from_config(Map.get(event_data, "index_file_decoder")),
      index_file_encoder:
        IndexFile.Encoder.from_config(Map.get(event_data, "index_file_encoder")),
      index_file_name: IndexFile.Name.from_config(Map.get(event_data, "index_file_name")),
      index_file_reader: IndexFile.Reader.from_config(Map.get(event_data, "index_file_reader")),
      index_file_writer: IndexFile.Writer.from_config(Map.get(event_data, "index_file_writer")),
      ledger_file_decoder:
        LedgerFile.Decoder.from_config(Map.get(event_data, "ledger_file_decoder")),
      ledger_file_encoder:
        LedgerFile.Encoder.from_config(Map.get(event_data, "ledger_file_encoder")),
      ledger_file_name: LedgerFile.Name.from_config(Map.get(event_data, "ledger_file_name")),
      ledger_file_reader:
        LedgerFile.Reader.from_config(Map.get(event_data, "ledger_file_reader")),
      ledger_file_writer:
        LedgerFile.Writer.from_config(Map.get(event_data, "ledger_file_writer")),
      lock_file_decoder: LockFile.Decoder.from_config(Map.get(event_data, "lock_file_decoder")),
      lock_file_encoder: LockFile.Encoder.from_config(Map.get(event_data, "lock_file_encoder")),
      lock_file_name: LockFile.Name.from_config(Map.get(event_data, "lock_file_name")),
      lock_file_reader: LockFile.Reader.from_config(Map.get(event_data, "lock_file_reader")),
      lock_file_writer: LockFile.Writer.from_config(Map.get(event_data, "lock_file_writer")),
      record_file_decoder:
        RecordFile.Decoder.from_config(Map.get(event_data, "record_file_decoder")),
      record_file_encoder:
        RecordFile.Encoder.from_config(Map.get(event_data, "record_file_encoder")),
      record_file_name: RecordFile.Name.from_config(Map.get(event_data, "record_file_name")),
      record_file_reader:
        RecordFile.Reader.from_config(Map.get(event_data, "record_file_reader")),
      record_file_schema:
        RecordFile.Schema.from_config(Map.get(event_data, "record_file_schema")),
      record_file_writer:
        RecordFile.Writer.from_config(Map.get(event_data, "record_file_writer")),
      storage_layout: StorageLayout.from_config(Map.get(event_data, "storage_layout"))
    }
  end

  def pubsub(%__MODULE__{database_id: id}) do
    Module.concat(Fact.PubSub, id)
  end

  def registry(%__MODULE__{database_id: id}) do
    Module.concat(Fact.Registry, id)
  end

  def via(%__MODULE__{} = context, key) do
    {:via, Registry, {registry(context), key}}
  end

  def last_store_position(%__MODULE__{} = context) do
    with stream <- Fact.LedgerFile.read(context, direction: :backward, position: :end, count: 1),
         event <- Fact.RecordFile.read_event(context, stream |> Enum.at(0)) do
      Fact.RecordFile.Schema.get_event_store_position(context, event)
    end
  end

  def read_query(%__MODULE__{} = context, query, opts \\ []) do
    {maybe_count, read_ledger_opts} = Keyword.split(opts, [:count])
    predicate = query.(context)

    Fact.LedgerFile.read(context, read_ledger_opts)
    |> Stream.filter(&predicate.(&1))
    |> take(Keyword.get(maybe_count, :count, :all))
  end

  defp take(stream, count) do
    case count do
      :all ->
        stream

      n ->
        Stream.take(stream, n)
    end
  end
end
