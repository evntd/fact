defmodule Fact.IndexFile.Decoder do
  use Fact.Seam.Decoder.Adapter,
    context: :index_file_decoder,
    allowed_impls: [{:raw, 1}]
end
