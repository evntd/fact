defmodule Fact.IndexCheckpointFileContent do
  use Fact.Seam.FileContent.Adapter,
      context: :index_checkpoint_file_content,
      registry: Fact.Seam.FileContent.Registry,
      allowed_impls: [{:integer, 1}]
end
