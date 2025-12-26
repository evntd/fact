defmodule Fact.IndexFileDecoder do
  use Fact.Seam.Decoder.Adapter,
    context: :index_file_decoder,
    allowed_impls: [{:raw, 1}]
end
