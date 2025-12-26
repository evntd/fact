defmodule Fact.IndexFile.Name do
  use Fact.Seam.FileName.Adapter,
    context: :index_file_name,
    allowed_impls: [
      {:raw, 1},
      {:hash, 1}
    ],
    default_impl: {:raw, 1}
end
