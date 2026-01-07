defmodule Fact.Genesis.Event.DatabaseCreated.V1 do
  alias Fact.Event
  alias Fact.IndexCheckpointFile
  alias Fact.IndexFile
  alias Fact.LedgerFile
  alias Fact.LockFile
  alias Fact.RecordFile
  alias Fact.Storage

  @keys [
    :database_id,
    :database_name,
    :elixir_version,
    :erts_version,
    :fact_version,
    :os_version,
    :otp_version,
    :event_id,
    :event_schema,
    :index_checkpoint_file_decoder,
    :index_checkpoint_file_encoder,
    :index_checkpoint_file_name,
    :index_checkpoint_file_reader,
    :index_checkpoint_file_writer,
    :index_file_decoder,
    :index_file_encoder,
    :index_file_name,
    :index_file_reader,
    :index_file_writer,
    :ledger_file_decoder,
    :ledger_file_encoder,
    :ledger_file_name,
    :ledger_file_reader,
    :ledger_file_writer,
    :lock_file_decoder,
    :lock_file_encoder,
    :lock_file_name,
    :lock_file_reader,
    :lock_file_writer,
    :record_file_decoder,
    :record_file_encoder,
    :record_file_name,
    :record_file_reader,
    :record_file_writer,
    :storage
  ]

  @enforce_keys @keys
  defstruct @keys

  @type component_config :: %{
          required(:family) => :atom,
          required(:version) => :positive_integer,
          required(:options) => map()
        }

  @type t :: %__MODULE__{
          database_id: Fact.database_id(),
          database_name: String.t(),
          elixir_version: String.t(),
          erts_version: String.t(),
          fact_version: String.t(),
          os_version: String.t(),
          otp_version: String.t(),
          event_id: component_config(),
          event_schema: component_config(),
          index_checkpoint_file_decoder: component_config(),
          index_checkpoint_file_encoder: component_config(),
          index_checkpoint_file_name: component_config(),
          index_checkpoint_file_reader: component_config(),
          index_checkpoint_file_writer: component_config(),
          index_file_decoder: component_config(),
          index_file_encoder: component_config(),
          index_file_name: component_config(),
          index_file_reader: component_config(),
          index_file_writer: component_config(),
          ledger_file_decoder: component_config(),
          ledger_file_encoder: component_config(),
          ledger_file_name: component_config(),
          ledger_file_reader: component_config(),
          ledger_file_writer: component_config(),
          lock_file_decoder: component_config(),
          lock_file_encoder: component_config(),
          lock_file_name: component_config(),
          lock_file_reader: component_config(),
          lock_file_writer: component_config(),
          record_file_decoder: component_config(),
          record_file_encoder: component_config(),
          record_file_name: component_config(),
          record_file_reader: component_config(),
          record_file_writer: component_config(),
          storage: component_config()
        }

  def to_context(%__MODULE__{} = event) do
    %Fact.Context{
      database_id: event.database_id,
      database_name: event.database_name,
      elixir_version: event.elixir_version,
      erts_version: event.erts_version,
      fact_version: event.fact_version,
      otp_version: event.otp_version,
      os_version: event.os_version,
      event_id: Event.Id.from_config(event.event_id),
      event_schema: Event.Schema.from_config(event.event_schema),
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
      storage: Storage.from_config(event.storage)
    }
  end
end
