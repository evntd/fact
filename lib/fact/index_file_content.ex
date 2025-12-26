defmodule Fact.IndexFileContent do
  use Fact.Seam.FileContent.Adapter,
    context: :index_file_content,
    registry: Fact.Seam.FileContent.Registry,
    allowed_impls: [{:delimited, 1}]
end
