defmodule Fact.IndexCheckpointFile do
  alias Fact.Context
  alias Fact.StorageLayout

  defmodule Decoder do
    use Fact.Seam.Decoder.Adapter,
      context: :index_checkpoint_file_decoder,
      allowed_impls: [{:integer, 1}]
  end

  defmodule Encoder do
    use Fact.Seam.Encoder.Adapter,
      context: :index_checkpoint_file_encoder,
      allowed_impls: [{:integer, 1}]
  end

  defmodule Name do
    use Fact.Seam.FileName.Adapter,
      context: :index_checkpoint_file_name,
      allowed_impls: [{:fixed, 1}],
      fixed_options: %{
        {:fixed, 1} => %{name: ".checkpoint"}
      }

    def get(%Context{} = context), do: get(context, nil, [])
  end

  defmodule Reader do
    use Fact.Seam.FileReader.Adapter,
      context: :index_checkpoint_file_reader,
      allowed_impls: [{:full, 1}]
  end

  defmodule Writer do
    use Fact.Seam.FileWriter.Adapter,
      context: :index_checkpoint_file_writer,
      fixed_options: %{
        {:standard, 1} => %{
          access: :write,
          binary: true,
          exclusive: false,
          raw: false,
          sync: true,
          worm: false
        }
      }
  end

  def ensure_exists(%Context{} = context, indexer) do
    with {:ok, path} <- path(context, indexer),
         :ok = File.mkdir_p(Path.dirname(path)) do
      unless File.exists?(path),
        do: File.write(path, "0"),
        else: :ok
    end
  end

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
    with {:ok, checkpoint_file} <- Name.get(context) do
      {:ok,
       Path.join([
         StorageLayout.indices_path(context),
         to_string(indexer_mod),
         to_string(indexer_key),
         checkpoint_file
       ])}
    end
  end

  defp read_single(%Context{} = context, path) do
    with {:ok, stream} <- Reader.read(context, path, []) do
      stream |> Enum.at(0)
    end
  end
end
