defmodule Fact.LedgerFile do
  alias Fact.Context
  alias Fact.LedgerFile.Decoder
  alias Fact.LedgerFile.Encoder
  alias Fact.LedgerFile.Name
  alias Fact.LedgerFile.Reader
  alias Fact.LedgerFile.Writer
  alias Fact.StorageLayout

  def read(%Context{} = context, opts \\ []) when is_list(opts) do
    {:ok, stream} =
      Reader.read(
        context,
        path(context),
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

  def write(%Context{} = context, record_ids) do
    case Writer.write(context, path(context), Encoder.encode(context, record_ids)) do
      :ok ->
        {:ok, record_ids}

      {:error, _} = error ->
        error
    end
  end

  defp path(%Context{} = context) do
    Path.join(StorageLayout.ledger_path(context), Name.get(context))
  end
end
