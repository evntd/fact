defmodule Fact.RecordFile do
  alias Fact.Context
  alias Fact.Storage

  defmodule Decoder do
    use Fact.Seam.Decoder.Adapter,
      context: :record_file_decoder,
      allowed_impls: [{:json, 1}]
  end

  defmodule Encoder do
    use Fact.Seam.Encoder.Adapter,
      context: :record_file_encoder,
      allowed_impls: [{:json, 1}]
  end

  defmodule Name do
    use Fact.Seam.FileName.Adapter,
      context: :record_file_name,
      allowed_impls: [{:hash, 1}, {:event_id, 1}],
      default_impl: {:event_id, 1}

    alias Fact.Context
    alias Fact.Seam.Instance

    def get(
          %Context{record_file_name: %Instance{module: mod}} = context,
          {event_record, encoded_record} = value
        )
        when is_tuple(value) do
      if :hash == mod.family() do
        get(context, encoded_record, [])
      else
        get(context, event_record, [])
      end
    end
  end

  defmodule Reader do
    use Fact.Seam.FileReader.Adapter,
      context: :record_file_reader,
      allowed_impls: [{:full, 1}]
  end

  defmodule Writer do
    use Fact.Seam.FileWriter.Adapter,
      context: :record_file_writer,
      fixed_options: %{
        {:standard, 1} => %{
          access: :write,
          binary: true,
          exclusive: true,
          raw: true,
          sync: true,
          worm: true
        }
      }
  end

  def read(database_id, record_id) do
    with {:ok, context} <- Fact.Registry.get_context(database_id),
         {:ok, record_path} <- path(context, record_id),
         {:ok, encoded_record} <- read_single(context, record_path),
         {:ok, record} <- Decoder.decode(context, encoded_record) do
      {record_id, record}
    end
  end

  def read_event(database_id, record_id) do
    {^record_id, record} = read(database_id, record_id)
    record
  end

  defp read_single(%Context{} = context, path) do
    with {:ok, stream} <- Reader.read(context, path, []) do
      {:ok, stream |> Enum.at(0)}
    end
  end

  def write(database_id, records) when is_binary(database_id) do
    with {:ok, context} <- Fact.Registry.get_context(database_id) do
      write(context, records)
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
    {:ok, Path.join(Storage.records_path(context), record_id)}
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
