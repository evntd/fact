defmodule Fact.Context do
  @moduledoc """
  The context for a Fact database.

  A `Fact.Context` holds all the configuration, file handlers, encoders/decoders,
  and metadata necessary to operate a database instance. It provides a central
  place to access:

    * Database identity and versioning information
    * Event and record schemas
    * File and storage handlers for ledgers, records, indexes, checkpoints, and locks
  """

  alias Fact.Event
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
    :event_schema,

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
      os_version: Map.get(event_data, "os_version"),
      otp_version: Map.get(event_data, "otp_version"),
      event_id: Event.Id.from_config(Map.get(event_data, "event_id")),
      event_schema: Event.Schema.from_config(Map.get(event_data, "event_schema")),
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
      record_file_writer:
        RecordFile.Writer.from_config(Map.get(event_data, "record_file_writer")),
      storage: Storage.from_config(Map.get(event_data, "storage"))
    }
  end
end
