defmodule Fact.IndexCheckpointFile.Encoder do
  use Fact.Seam.Encoder.Adapter,
    context: :index_checkpoint_file_encoder,
    allowed_impls: [{:integer, 1}]
end
