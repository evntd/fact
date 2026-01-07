defmodule Fact.LedgerFile do
  @moduledoc """
  Domain-specific module that encapsulates configurable adapters for 
  working with ledger file.
    
  This provides helper functions to make it easier than directly working 
  with the adapters and `Fact.Context` modules. 
  """
  alias Fact.Context
  alias Fact.Storage

  defmodule Decoder do
    @moduledoc """
    Adapter for decoding the contents of ledger file.
      
    There is currently only a single **allowed** implementation, see `Fact.Seam.Decoder.Raw.V1`.
    """
    use Fact.Seam.Decoder.Adapter,
      context: :ledger_file_decoder,
      allowed_impls: [{:raw, 1}]
  end

  defmodule Encoder do
    @moduledoc """
    Adapter for encoding the contents of ledger file.

    There is currently only a single **allowed** implementation, see `Fact.Seam.Encoder.Delimited.V1`.
    """
    use Fact.Seam.Encoder.Adapter,
      context: :ledger_file_encoder,
      allowed_impls: [{:delimited, 1}]
  end

  defmodule Name do
    @moduledoc """
    Adapter for naming the ledger file within the file system.
      
    There is currently only a single **allowed** implementation, see `Fact.Seam.Encoder.Fixed.V1`.
    """
    use Fact.Seam.FileName.Adapter,
      context: :ledger_file_name,
      allowed_impls: [{:fixed, 1}],
      fixed_options: %{
        {:fixed, 1} => %{name: ".ledger"}
      }

    def get(%Context{} = context), do: get(context, nil, [])
  end

  defmodule Reader do
    @moduledoc """
    Adapter for reading the contents of the ledger file.
      
    There is currently only a single **allowed** implementation, see `Fact.Seam.FileReader.FixedLength.V1`.
    """
    use Fact.Seam.FileReader.Adapter,
      context: :ledger_file_reader,
      allowed_impls: [{:fixed_length, 1}]
  end

  defmodule Writer do
    @moduledoc """
    Adapter for writing the contents of ledger file to the file system.
      
    There is currently only a single **allowed** implementation, see `Fact.Seam.FileWriter.Standard.V1`.
      
    The ledger file opened for append-only writes using raw file descriptors, and each write is synchronously
    flushed to disk to ensure durability.
    """
    use Fact.Seam.FileWriter.Adapter,
      context: :ledger_file_writer,
      fixed_options: %{
        {:standard, 1} => %{
          access: :append,
          binary: true,
          exclusive: false,
          raw: true,
          sync: true,
          worm: false
        }
      }
  end

  def read(database, opts \\ [])

  def read(database_id, opts) when is_binary(database_id) and is_list(opts) do
    with {:ok, context} <- Fact.Registry.get_context(database_id) do
      read(context, opts)
    end
  end

  def read(%Context{} = context, opts) when is_list(opts) do
    with {:ok, path} <- path(context),
         {:ok, stream} <- Reader.read(context, path, Keyword.take(opts, [:direction, :position])) do
      decoded_stream =
        stream
        |> Stream.map(decode(context))

      case Keyword.get(opts, :count, :all) do
        :all ->
          decoded_stream

        n when is_integer(n) ->
          decoded_stream |> Stream.take(n)
      end
    end
  end

  def write(database_id, record_ids) when is_binary(database_id) do
    with {:ok, context} <- Fact.Registry.get_context(database_id) do
      write(context, record_ids)
    end
  end

  def write(%Context{} = context, record_ids) do
    with {:ok, path} <- path(context),
         {:ok, encoded} <- Encoder.encode(context, record_ids),
         :ok <- Writer.write(context, path, encoded) do
      {:ok, record_ids}
    end
  end

  defp path(%Context{} = context) do
    with {:ok, ledger_file} <- Name.get(context) do
      {:ok, Path.join(Storage.ledger_path(context), ledger_file)}
    end
  end

  defp decode(%Context{} = context) do
    fn encoded ->
      with {:ok, decoded} <- Decoder.decode(context, encoded), do: decoded
    end
  end
end
