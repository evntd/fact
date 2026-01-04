defmodule Fact.Context do
  alias Fact.EventId
  alias Fact.IndexCheckpointFile
  alias Fact.IndexFile
  alias Fact.LedgerFile
  alias Fact.LockFile
  alias Fact.RecordFile
  alias Fact.Storage

  defstruct [
    # Identity
    :database_id,
    :database_name,

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

    ## Storage
    :storage
  ]

  def from_record(%{"event_type" => "Elixir.Fact.Genesis.Event.DatabaseCreated.V1"} = record) do
    event_data = Map.get(record, "event_data")

    %__MODULE__{
      database_id: Map.get(event_data, "database_id"),
      database_name: Map.get(event_data, "database_name"),
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
      storage: Storage.from_config(Map.get(event_data, "storage"))
    }
  end

  def pubsub(database_id) when is_binary(database_id) do
    Module.concat(Fact.PubSub, database_id)
  end

  def registry(database_id) when is_binary(database_id) do
    Module.concat(Fact.Registry, database_id)
  end

  def supervisor(database_id) when is_binary(database_id) do
    Module.concat(Fact.DatabaseSupervisor, database_id)
  end

  def via(database_id, key) when is_binary(database_id) do
    {:via, Registry, {registry(database_id), key}}
  end
end
