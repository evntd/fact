defmodule Fact.IndexCheckpointFile.Reader do
  use Fact.Seam.FileReader.Adapter,
    context: :index_checkpoint_file_reader,
    allowed_impls: [{:full, 1}]

  def read_one(%Context{} = context, path) do
    with {:ok, stream} <- read(context, path, []) do
      stream |> Enum.at(0)
    end
  end
end
