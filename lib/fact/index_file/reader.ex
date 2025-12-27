defmodule Fact.IndexFile.Reader do
  use Fact.Seam.FileReader.Adapter,
    context: :index_file_reader,
    allowed_impls: [{:fixed_length, 1}]
end
