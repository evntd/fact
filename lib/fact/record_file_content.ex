defmodule Fact.RecordFileContent do
  use Fact.Seam.FileContent.Adapter,
    context: :record_file_content,
    registry: Fact.Seam.FileContent.Registry,
    allowed_impls: [{:json, 1}]
end
