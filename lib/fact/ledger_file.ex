defmodule Fact.LedgerFile do
  alias Fact.Context
  alias Fact.LedgerFile.Decoder
  alias Fact.LedgerFile.Encoder
  alias Fact.LedgerFile.Name
  alias Fact.LedgerFile.Reader
  alias Fact.LedgerFile.Writer
  alias Fact.StorageLayout

  def read(%Context{} = context, opts \\ []) when is_list(opts) do
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

  def write(%Context{} = context, record_ids) do
    with {:ok, path} <- path(context),
         {:ok, encoded} <- Encoder.encode(context, record_ids),
         :ok <- Writer.write(context, path, encoded) do
      {:ok, record_ids}
    end
  end

  defp path(%Context{} = context) do
    with {:ok, ledger_path} <- StorageLayout.ledger_path(context),
         {:ok, ledger_file} <- Name.get(context) do
      {:ok, Path.join(ledger_path, ledger_file)}
    end
  end

  defp decode(%Context{} = context) do
    fn encoded ->
      with {:ok, decoded} <- Decoder.decode(context, encoded), do: decoded
    end
  end
end
