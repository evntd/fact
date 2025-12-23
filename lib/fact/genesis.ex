defmodule Fact.Genesis do
  def storage_layout, do: Fact.StorageLayout.Default.V1
  def ledger_filename, do: Fact.IndexFilename.Ledger.V1
  def ledger_file_format, do: Fact.IndexFileFormat.DelimitedList.V1
  def index_reader, do: Fact.IndexReader.Line.V1
  def record_file_format, do: Fact.RecordFile.Json.V1
  def record_schema, do: Fact.RecordSchema.Default.V1
end
