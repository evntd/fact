defmodule Fact.RecordFile do
  alias Fact.Context
  alias Fact.RecordFile.Decoder
  alias Fact.RecordFile.Encoder
  alias Fact.RecordFile.Name
  alias Fact.RecordFile.Reader
  alias Fact.RecordFile.Writer
  alias Fact.StorageLayout

  def read(%Context{} = context, record_id) do
    with {:ok, record_path} <- path(context, record_id),
         {:ok, encoded_record} <- read_single(context, record_path),
         {:ok, record} <- Decoder.decode(context, encoded_record) do
      {:ok, {record_id, record}}
    end
  end

  def read_event(%Context{} = context, record_id) do
    with {:ok, {^record_id, record}} <- read(context, record_id) do
      {:ok, record}
    end
  end

  defp read_single(%Context{} = context, path) do
    with {:ok, stream} <- Reader.read(context, path, []) do
      {:ok, stream |> Enum.at(0)}
    end
  end

  def write(%Context{} = context, records) when is_list(records) do
    with write_results <-
           Task.async_stream(records, &write(context, &1),
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

  def write(%Context{} = context, record) do
    with {:ok, encoded_record} <- Encoder.encode(context, record),
         {:ok, record_id} <- Name.get(context, {record, encoded_record}),
         {:ok, record_path} <- path(context, record_id),
         :ok <- Writer.write(context, record_path, encoded_record) do
      {:ok, record_id}
    end
  end

  defp path(context, record_id) do
    {:ok, path} = StorageLayout.records_path(context)
    {:ok, Path.join(path, record_id)}
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
