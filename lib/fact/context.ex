defmodule Fact.Context do
  defstruct [
    # Identity
    :database_id,
    :database_name,
    # Addressing
    :database_path,

    # Seams (instances -> modules + structs)
    :index_file_content_format,
    :index_file_name_format,
    :index_file_reader,    
    :ledger_file_content_format,
    :record_file_content_format,
    :record_file_name_format,
    :record_schema_format,
    :storage_layout_format
  ]
end
