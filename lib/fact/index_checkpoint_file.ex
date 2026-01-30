defmodule Fact.IndexCheckpointFile do
  @moduledoc """
  Domain-specific module that encapsulates configurable adapters for 
  working with index checkpoint files.
    
  This provides helper functions to make it easier than directly working 
  with the adapters and `Fact.Context` modules. 
  """
  alias Fact.Context
  alias Fact.Storage

  defmodule Decoder do
    @moduledoc """
    Adapter for decoding the contents of index checkpoint files.
      
    There is currently only a single **allowed** implementation, see `Fact.Seam.Decoder.Integer.V1`.
    """
    use Fact.Seam.Decoder.Adapter,
      context: :index_checkpoint_file_decoder,
      allowed_impls: [{:integer, 1}]
  end

  defmodule Encoder do
    @moduledoc """
    Adapter for encoding the contents of index checkpoint files.

    There is currently only a single **allowed** implementation, see `Fact.Seam.Encoder.Integer.V1`.
    """
    use Fact.Seam.Encoder.Adapter,
      context: :index_checkpoint_file_encoder,
      allowed_impls: [{:integer, 1}]
  end

  defmodule Name do
    @moduledoc """
    Adapter for naming the index checkpoint files within the file system.
      
    There is currently only a single **allowed** implementation, see `Fact.Seam.Encoder.Fixed.V1`.
    """
    use Fact.Seam.FileName.Adapter,
      context: :index_checkpoint_file_name,
      allowed_impls: [{:fixed, 1}],
      fixed_options: %{
        {:fixed, 1} => %{name: ".checkpoint"}
      }

    def get(%Context{} = context), do: get(context, nil, [])
  end

  defmodule Reader do
    @moduledoc """
    Adapter for reading the contents of index checkpoint files.
      
    There is currently only a single **allowed** implementation, see `Fact.Seam.FileReader.Full.V1`.
    """
    use Fact.Seam.FileReader.Adapter,
      context: :index_checkpoint_file_reader,
      allowed_impls: [{:full, 1}]
  end

  defmodule Writer do
    @moduledoc """
    Adapter for writing the contents of index checkpoint files to the file system.
      
    There is currently only a single **allowed** implementation, see `Fact.Seam.FileWriter.Standard.V1`.
      
    Index checkpoint files are opened in write mode, overwriting any existing contents.     

    As of Fact v0.2.1, the `sync` is now configurable, to allow configurable of non-durable writes, it still
    defaults to true, but may be set to false. When false, fsync will not be called, and this should increase
    write throughput.
    """
    @moduledoc since: "0.2.1"
    use Fact.Seam.FileWriter.Adapter,
      context: :index_checkpoint_file_writer,
      default_options: %{sync: true},
      fixed_options: %{
        {:standard, 1} => %{
          access: :write,
          binary: true,
          exclusive: false,
          raw: false,
          worm: false
        }
      }
  end

  def ensure_exists(database_id, indexer) do
    with {:ok, context} <- Fact.Registry.get_context(database_id),
         {:ok, path} <- path(context, indexer),
         :ok = File.mkdir_p(Path.dirname(path)) do
      unless File.exists?(path),
        do: File.write(path, "0"),
        else: :ok
    end
  end

  def read(database_id, indexer) do
    with {:ok, context} <- Fact.Registry.get_context(database_id),
         {:ok, path} <- path(context, indexer),
         {:ok, encoded} <- read_single(context, path),
         {:ok, decoded} <- Decoder.decode(context, encoded) do
      decoded
    else
      {:error, :enoent} -> 0
    end
  end

  def write(database_id, indexer, position) do
    with {:ok, context} <- Fact.Registry.get_context(database_id),
         {:ok, path} <- path(context, indexer),
         {:ok, encoded} = Encoder.encode(context, position),
         :ok <- Writer.write(context, path, encoded) do
      :ok
    end
  end

  defp path(%Context{} = context, {indexer_mod, indexer_key}) do
    with {:ok, checkpoint_file} <- Name.get(context) do
      {:ok,
       Path.join([
         Storage.indices_path(context),
         indexer_mod.indexer_name(),
         to_string(indexer_key),
         checkpoint_file
       ])}
    end
  end

  defp read_single(%Context{} = context, path) do
    with {:ok, stream} <- Reader.read(context, path, []) do
      {:ok, stream |> Enum.at(0)}
    end
  end
end
