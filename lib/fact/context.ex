defmodule Fact.Context do
  defstruct [
    # Identity
    :database_id,
    :database_name,
    # Addressing
    :database_path,

    # Seams (instances -> modules + structs)
    :index_file_format,
    :index_file_reader,
    :index_file_name,
    :record_file_format,
    :record_file_name,
    :record_schema,
    :storage_layout
  ]
end
