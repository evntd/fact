defmodule Fact.IndexFile.Encoder do
  use Fact.Seam.Encoder.Adapter,
    context: :index_file_encoder,
    allowed_impls: [{:delimited, 1}]
end
