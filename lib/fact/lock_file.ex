defmodule Fact.LockFile do
  @moduledoc """
  Domain-specific module that encapsulates configurable adapters for 
  working with lock files.
    
  This provides helper functions to make it easier than working with 
  adapters and `Fact.Context` module.
  """
  alias Fact.Context
  alias Fact.Storage

  defmodule Decoder do
    @moduledoc """
    Adapter for decoding the contents of lock file.
      
    There is currently only a single **allowed** implementation, see `Fact.Seam.Decoder.Json.V1`.
    """
    use Fact.Seam.Decoder.Adapter,
      context: :lock_file_decoder,
      allowed_impls: [{:json, 1}]
  end

  defmodule Encoder do
    @moduledoc """
    Adapter for encoding the contents of lock file.

    There is currently only a single **allowed** implementation, see `Fact.Seam.Encoder.Json.V1`.
    """
    use Fact.Seam.Encoder.Adapter,
      context: :lock_file_encoder,
      allowed_impls: [{:json, 1}]
  end

  defmodule Name do
    @moduledoc """
    Adapter for naming the lock file within the file system.
      
    There is currently only a single **allowed** implementation, see `Fact.Seam.Encoder.Fixed.V1`.
    """
    use Fact.Seam.FileName.Adapter,
      context: :lock_file_name,
      allowed_impls: [{:fixed, 1}],
      fixed_options: %{
        {:fixed, 1} => %{name: "lock"}
      }

    def get(%Context{} = context), do: get(context, nil, [])
  end

  defmodule Reader do
    @moduledoc """
    Adapter for reading the contents of the lock file.
      
    There is currently only a single **allowed** implementation, see `Fact.Seam.FileReader.Full.V1`.
    """
    use Fact.Seam.FileReader.Adapter,
      context: :lock_file_reader,
      allowed_impls: [{:full, 1}]
  end

  defmodule Writer do
    @moduledoc """
    Adapter for writing the contents of the lock file to the file system.
      
    There is currently only a single **allowed** implementation, see `Fact.Seam.FileWriter.Standard.V1`.
      
    The lock file is opened in write mode, overwriting any existing contents. Although the lock file
    is normally deleted when the lock is released, certain failure scenarios may leave a stale lock
    file behind. 
    """
    use Fact.Seam.FileWriter.Adapter,
      context: :lock_file_writer,
      fixed_options: %{
        {:standard, 1} => %{
          access: :write,
          binary: true,
          exclusive: false,
          raw: false,
          sync: false,
          worm: false
        }
      }
  end

  def delete(database_id) when is_binary(database_id) do
    with {:ok, context} <- Fact.Registry.get_context(database_id),
         {:ok, filepath} <- path(context) do
      File.rm(filepath)
    end
  end

  def read(database_id) when is_binary(database_id) do
    with {:ok, context} <- Fact.Registry.get_context(database_id) do
      read(context)
    end
  end

  def read(%Context{} = context) do
    with {:ok, filepath} <- path(context),
         {:ok, stream} <- Reader.read(context, filepath, []),
         encoded <- stream |> Enum.at(0),
         {:ok, content} <- Decoder.decode(context, encoded) do
      content
    end
  end

  def write(database_id, lock_info) do
    with {:ok, context} <- Fact.Registry.get_context(database_id),
         {:ok, encoded} <- Encoder.encode(context, lock_info),
         {:ok, filepath} <- path(context),
         :ok <- Writer.write(context, filepath, encoded) do
      :ok
    end
  end

  defp path(%Context{} = context) do
    with {:ok, filename} <- Name.get(context) do
      {:ok, Path.join(Storage.locks_path(context), filename)}
    end
  end
end
