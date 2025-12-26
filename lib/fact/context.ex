defmodule Fact.Context do
  defstruct [
    # Identity
    :database_id,
    :database_name,
    # Addressing
    :database_path,

    # Seams 

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
      database_path: Path.absname(path),
      index_checkpoint_file_decoder: Fact.IndexCheckpointFile.Decoder.init(),
      index_checkpoint_file_encoder: Fact.IndexCheckpointFile.Encoder.init(),
      index_checkpoint_file_name: Fact.IndexCheckpointFile.Name.init(),
      index_checkpoint_file_reader: Fact.IndexCheckpointFile.Reader.init(),
      index_checkpoint_file_writer: Fact.IndexCheckpointFile.Writer.init(),
      index_file_decoder: Fact.IndexFile.Decoder.init(),
      index_file_encoder: Fact.IndexFile.Encoder.init(),
      index_file_name: Fact.IndexFile.Name.init(),
      index_file_reader: Fact.IndexFile.Reader.init(),
      index_file_writer: Fact.IndexFile.Writer.init(),
      ledger_file_decoder: Fact.LedgerFile.Decoder.init(),
      ledger_file_encoder: Fact.LedgerFile.Encoder.init(),
      ledger_file_name: Fact.LedgerFile.Name.init(),
      ledger_file_reader: Fact.LedgerFile.Reader.init(),
      ledger_file_writer: Fact.LedgerFile.Writer.init(),
      record_file_decoder: Fact.RecordFile.Decoder.init(),
      record_file_encoder: Fact.RecordFile.Encoder.init(),
      record_file_name: Fact.RecordFile.Name.init(),
      record_file_reader: Fact.RecordFile.Reader.init(),
      record_file_writer: Fact.RecordFile.Writer.init(),
      record_file_schema: Fact.RecordFile.Schema.init(),
      storage_layout: Fact.StorageLayout.init()
    }
  end
end
