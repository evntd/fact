defmodule Fact.IndexCheckpointFile.Decoder do
  use Fact.Seam.Decoder.Adapter,
    context: :index_checkpoint_file_decoder,
    allowed_impls: [{:integer, 1}]
end
