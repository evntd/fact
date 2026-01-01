defmodule Fact.IndexFile do
  alias Fact.Context
  alias Fact.IndexFile.Decoder
  alias Fact.IndexFile.Encoder
  alias Fact.IndexFile.Name
  alias Fact.IndexFile.Reader
  alias Fact.IndexFile.Writer
  alias Fact.StorageLayout

  def read(%Context{} = context, indexer, index, opts \\ []) when is_list(opts) do
    with {:ok, path} <- path(context, indexer, index),
         {:ok, stream} <- Reader.read(context, path, Keyword.take(opts, [:direction, :position])) do
      decoded_stream =
        stream
        |> Stream.map(decode(context))

      case Keyword.get(opts, :count, :all) do
        :all ->
          {:ok, decoded_stream}

        n when is_integer(n) ->
          Stream.take(decoded_stream, n)
      end
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
    with {:ok, indices_path} <- StorageLayout.indices_path(context),
         {:ok, index_file} <- Name.get(context, index) do
      {:ok,
       Path.join([
         indices_path,
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
