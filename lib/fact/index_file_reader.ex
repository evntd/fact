defmodule Fact.IndexFileReader do
  use Fact.Seam.FileReader.Adapter,
    context: :index_file_reader,
    allowed_impls: [{:fixed_size, 1}]
end
