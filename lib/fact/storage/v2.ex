defmodule Fact.Storage.V2 do
  @moduledoc false

  @spec write_event(%Fact.Context{}, Fact.Types.event_record()) ::
          {:ok, Fact.Types.record_id()} | {:error, term()}
  def write_event(%Fact.Context{} = context, event_record) do
    case Fact.RecordFileContent.encode(context, event_record) do
      {:ok, encoded_record} ->
        with record_id <- Fact.RecordFileName.get(context, event_record, encoded_record),
             record_path <- Fact.StorageLayout.record_path(context, record_id) do
          case write_sync(record_path, encoded_record, [:write, :binary, :exclusive]) do
            :ok ->
              {:ok, record_id}

            {:error, reason} ->
              {:error, {reason, record_id}}
          end
        end

      {:error, reason} ->
        {:error, {:encode_failed, reason}}
    end
  end

  def write_events(%Fact.Context{} = context, event_records) do
    with write_results <-
           Task.async_stream(event_records, &write_event(context, &1),
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

  def write_ledger(%Fact.Context{} = context, record_ids) do
    case Fact.LedgerFileContent.encode(context, record_ids) do
      {:ok, content} ->
        with path <- Fact.StorageLayout.ledger_path(context) do
          case write_sync(path, content, [:append, :binary]) do
            :ok ->
              {:ok, record_ids}

            {:error, _} = error ->
              error
          end
        end

      {:error, reason} ->
        {:error, {:encode_failed, reason}}
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

  @spec write_sync(Path.t(), iodata(), [File.mode()]) :: :ok | {:error, term()}
  defp write_sync(path, content, modes) do
    case File.open(path, modes) do
      {:ok, fd} ->
        try do
          with :ok <- IO.binwrite(fd, content),
               :ok <- :file.sync(fd) do
            :ok
          else
            {:error, reason} -> {:error, reason}
          end
        after
          File.close(fd)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end
