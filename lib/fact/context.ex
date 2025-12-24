defmodule Fact.Context do
  defstruct [
    # Identity
    :database_id,
    :database_name,
    # Addressing
    :database_path,

    # Seams (instances -> modules + structs)
    :index_checkpoint_file_content,
    :index_checkpoint_file_name,
    :index_checkpoint_file_reader,
    :index_checkpoint_file_writer,
    :index_file_content,
    :index_file_name,
    :index_file_reader,
    :index_file_writer,
    :ledger_file_content,
    :ledger_file_name,
    :ledger_file_reader,
    :ledger_file_writer,
    :record_file_content,
    :record_file_name,
    :record_file_reader,
    :record_file_writer,
    :record_schema,
    :storage_layout
  ]
end
