defmodule Fact.IndexFile do
  alias Fact.Context
  alias Fact.Storage

  defmodule Decoder do
    use Fact.Seam.Decoder.Adapter,
      context: :index_file_decoder,
      allowed_impls: [{:raw, 1}]
  end

  defmodule Encoder do
    use Fact.Seam.Encoder.Adapter,
      context: :index_file_encoder,
      allowed_impls: [{:delimited, 1}]
  end

  defmodule Name do
    use Fact.Seam.FileName.Adapter,
      context: :index_file_name,
      allowed_impls: [
        {:raw, 1},
        {:hash, 1}
      ],
      default_impl: {:raw, 1}

    def get(%Context{} = context, value), do: get(context, value, [])
  end

  defmodule Reader do
    use Fact.Seam.FileReader.Adapter,
      context: :index_file_reader,
      allowed_impls: [{:fixed_length, 1}]
  end

  defmodule Writer do
    use Fact.Seam.FileWriter.Adapter,
      context: :index_file_writer,
      fixed_options: %{
        {:standard, 1} => %{
          access: :append,
          binary: true,
          exclusive: false,
          raw: false,
          sync: false,
          worm: false
        }
      }
  end

  def read(database_id, indexer, index, opts \\ []) when is_list(opts) do
    with {:ok, context} <- Fact.Registry.get_context(database_id),
         {:ok, path} <- path(context, indexer, index),
         {:ok, stream} <- Reader.read(context, path, Keyword.take(opts, [:direction, :position])) do
      decoded_stream =
        stream
        |> Stream.map(decode(context))

      case Keyword.get(opts, :count, :all) do
        :all ->
          decoded_stream

        n when is_integer(n) ->
          Stream.take(decoded_stream, n)
      end
    end
  end

  def read_last_event(database_id, indexer, index) do
    with {:ok, context} <- Fact.Registry.get_context(database_id) do
      read(context, indexer, index, direction: :backward, position: :end, count: 1)
      |> Stream.map(&Fact.RecordFile.read_event(context, &1))
      |> Enum.at(0)
    end
  end

  def write(database_id, indexer, index, record_ids) when is_binary(database_id) do
    with {:ok, context} <- Fact.Registry.get_context(database_id) do
      write(context, indexer, index, record_ids)
    end
  end

  def write(%Context{} = context, indexer, index, record_ids) do
    with {:ok, path} <- path(context, indexer, index),
         {:ok, encoded} <- Encoder.encode(context, record_ids),
         :ok <- Writer.write(context, path, encoded) do
      {:ok, record_ids}
    end
  end

  defp path(%Context{} = context, {indexer_mod, indexer_key}, index) do
    with {:ok, index_file} <- Name.get(context, index) do
      {:ok,
       Path.join([
         Storage.indices_path(context),
         to_string(indexer_mod),
         to_string(indexer_key),
         index_file
       ])}
    end
  end

  defp decode(%Context{} = context) do
    fn encoded ->
      with {:ok, decoded} <- Decoder.decode(context, encoded), do: decoded
    end
  end
end
