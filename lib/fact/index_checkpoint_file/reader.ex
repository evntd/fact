defmodule Fact.IndexCheckpointFile.Reader do
  use Fact.Seam.FileReader.Adapter,
    context: :index_checkpoint_file_reader,
    allowed_impls: [{:full, 1}]

  
end
