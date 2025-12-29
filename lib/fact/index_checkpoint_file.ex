defmodule Fact.IndexCheckpointFile do
  alias Fact.Context
  alias Fact.IndexCheckpointFile.Decoder
  alias Fact.IndexCheckpointFile.Encoder
  alias Fact.IndexCheckpointFile.Name
  alias Fact.IndexCheckpointFile.Reader
  alias Fact.IndexCheckpointFile.Writer
  alias Fact.StorageLayout

  def read(%Context{} = context, indexer) do
    path = path(context, indexer)    
    encoded = read_single(context, path)    
    Decoder.decode(context, encoded)
  end
  
  def write(%Context{} = context, indexer, position) do
    encoded = Encoder.encode(context, position)
    path = path(context, indexer)
    Writer.write(context, path, encoded)    
  end
  
  defp path(%Context{} = context, {indexer_mod, indexer_key}) do
    Path.join([
      StorageLayout.indices_path(context),
      to_string(indexer_mod),
      to_string(indexer_key),
      Name.get(context, nil)])
  end

  defp read_single(%Context{} = context, path) do
    with {:ok, stream} <- Reader.read(context, path, []) do
      stream |> Enum.at(0)
    end
  end
end
