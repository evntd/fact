defmodule Fact.IndexCheckpointFileReader do
  use Fact.Seam.FileReader.Adapter,
    context: :index_checkpoint_file_reader,
    allowed_impls: [{:full, 1}]

  def read(%Context{} = context, path) do
    read(context, path, []) |> Enum.at(1)
  end
end
