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
    :record_schema,

    ## Storage Layout
    :storage_layout
  ]

  def init() do
    %__MODULE__{
      index_checkpoint_file_decoder: Fact.IndexCheckpointFileDecoder.init(),
      index_checkpoint_file_encoder: Fact.IndexCheckpointFileEncoder.init(),
      index_checkpoint_file_name: Fact.IndexCheckpointFileName.init(),
      index_checkpoint_file_reader: Fact.IndexCheckpointFileReader.init(),
      index_checkpoint_file_writer: Fact.IndexCheckpointFileWriter.init(),
      index_file_decoder: Fact.IndexFileDecoder.init(),
      index_file_encoder: Fact.IndexFileEncoder.init(),
      index_file_name: Fact.IndexFileName.init(),
      index_file_reader: Fact.IndexFileReader.init(),
      index_file_writer: Fact.IndexFileWriter.init(),
      ledger_file_decoder: Fact.LedgerFileDecoder.init(),
      ledger_file_encoder: Fact.LedgerFileEncoder.init(),
      ledger_file_name: Fact.LedgerFileName.init(),
      ledger_file_reader: Fact.LedgerFileReader.init(),
      ledger_file_writer: Fact.LedgerFileWriter.init(),
      record_file_decoder: Fact.RecordFileDecoder.init(),
      record_file_encoder: Fact.RecordFileEncoder.init(),
      record_file_name: Fact.RecordFileName.init(),
      record_file_reader: Fact.RecordFileReader.init(),
      record_file_writer: Fact.RecordFileWriter.init(),
      record_schema: Fact.RecordSchema.init(),
      storage_layout: Fact.StorageLayout.init()
    }
  end
end
