defmodule Fact.IndexCheckpointFile do
  alias Fact.Context
  alias Fact.IndexCheckpointFile.Decoder
  alias Fact.IndexCheckpointFile.Encoder
  alias Fact.IndexCheckpointFile.Name
  alias Fact.IndexCheckpointFile.Reader
  alias Fact.IndexCheckpointFile.Writer
  alias Fact.StorageLayout

  def read(%Context{} = context, indexer) do
    with {:ok, path} <- path(context, indexer),
         encoded <- read_single(context, path),
         {:ok, decoded} <- Decoder.decode(context, encoded) do
      decoded
    end
  end

  def write(%Context{} = context, indexer, position) do
    with {:ok, path} <- path(context, indexer),
         {:ok, encoded} = Encoder.encode(context, position),
         :ok <- Writer.write(context, path, encoded) do
      :ok
    end
  end

  defp path(%Context{} = context, {indexer_mod, indexer_key}) do
    with {:ok, indices_path} <- StorageLayout.indices_path(context),
         {:ok, checkpoint_file} <- Name.get(context) do
      {:ok,
       Path.join([indices_path, to_string(indexer_mod), to_string(indexer_key), checkpoint_file])}
    end
  end

  defp read_single(%Context{} = context, path) do
    with {:ok, stream} <- Reader.read(context, path, []) do
      stream |> Enum.at(0)
    end
  end
end
