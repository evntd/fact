defmodule Fact.IndexFile do
  alias Fact.Context
  alias Fact.IndexFile.Decoder
  alias Fact.IndexFile.Encoder
  alias Fact.IndexFile.Name
  alias Fact.IndexFile.Reader
  alias Fact.IndexFile.Writer
  alias Fact.StorageLayout

  def read(%Context{} = context, indexer, index, opts \\ []) when is_list(opts) do
    {:ok, stream} =
      Reader.read(
        context,
        path(context, indexer, index),
        Keyword.take(opts, [:direction, :position])
      )

    stream
    |> Stream.map(fn encoded ->
      {:ok, decoded} = Decoder.decode(context, encoded)
      decoded
    end)

    case Keyword.get(opts, :count, :all) do
      :all ->
        stream

      n when is_integer(n) ->
        Stream.take(stream, n)
    end
  end

  def write(%Context{} = context, indexer, index, record_ids) do
    path = path(context, indexer, index)
    encoded = Encoder.encode(context, record_ids)

    case Writer.write(context, path, encoded) do
      :ok ->
        {:ok, record_ids}

      {:error, _} = error ->
        error
    end
  end

  defp path(%Context{} = context, {indexer_mod, indexer_key}, index) do
    Path.join([
      StorageLayout.indices_path(context),
      to_string(indexer_mod),
      to_string(indexer_key),
      Name.get(context, index)
    ])
  end
end
