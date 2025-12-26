defmodule Fact.Storage.V2 do
  @moduledoc false

  alias Fact.Context
  alias Fact.RecordFile
  alias Fact.LedgerFile
  alias Fact.StorageLayout

  def read_record(%Context{} = context, record_id) do
    record_path = StorageLayout.record_path(context, record_id)
    encoded_record = RecordFile.Reader.read_one(context, record_path)
    {:ok, record} = RecordFile.Decoder.decode(context, encoded_record)
    {record_id, record}
  end

  def read_ledger(%Context{} = context) do
    ledger = Path.join(StorageLayout.ledger_path(context), LedgerFile.Name.get(context))

    {:ok, stream} = LedgerFile.Reader.read(context, ledger, size: 32, padding: 1)

    stream
    |> Stream.map(fn encoded ->
      {:ok, decoded} = LedgerFile.Decoder.decode(context, encoded)
      decoded
    end)
  end

  def write_ledger(%Context{} = context, record_ids) do
    ledger_file = Path.join(StorageLayout.ledger_path(context), LedgerFile.Name.get(context))
    ledger_entry = LedgerFile.Encoder.encode(context, record_ids)
    :ok = LedgerFile.Writer.write(context, ledger_file, ledger_entry)
    {:ok, record_ids}
  end

  @spec write_record(%Context{}, Fact.Types.event_record()) ::
          {:ok, Fact.Types.record_id()} | {:error, term()}
  def write_record(%Context{} = context, event_record) do
    encoded_record = RecordFile.Encoder.encode(context, event_record)
    record_id = RecordFile.Name.get(context, event_record, encoded_record)
    record_file = StorageLayout.record_path(context, record_id)
    :ok = RecordFile.Writer.write(context, record_file, encoded_record)
    {:ok, record_id}
  end

  @spec write_records(%Fact.Context{}, nonempty_list(Fact.Types.event_record())) ::
          {:ok, nonempty_list(Fact.Types.record_id())} | {:error, term()}
  def write_records(%Fact.Context{} = context, event_records) do
    with write_results <-
           Task.async_stream(event_records, &write_record(context, &1),
             max_concurrency: System.schedulers_online()
           ),
         {:ok, record_ids, []} <- process_write_results(write_results) do
      {:ok, Enum.reverse(record_ids)}
    else
      {:error, _, errors} ->
        {:error, {:event_write_failed, Enum.reverse(errors)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp process_write_results(results) do
    Enum.reduce(results, {:ok, [], []}, fn
      {_, {:ok, record_id}}, {result, records, errors} ->
        {result, [record_id | records], errors}

      {_, {:error, posix, record_id}}, {_, records, errors} ->
        {:error, records, [{posix, record_id} | errors]}
    end)
  end
end
