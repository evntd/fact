defmodule Fact.Storage do
  @moduledoc false

  @default_driver Fact.Storage.Driver.ByEventId
  @default_format Fact.Storage.Format.Json

  def child_spec(opts) do
    %{
      id: {__MODULE__, Keyword.fetch!(opts, :instance)},
      start: {__MODULE__, :start_link, [opts]},
      type: :worker
    }
  end

  def start_link(opts) do
    instance = Keyword.fetch!(opts, :instance)
    events_path = Keyword.fetch!(opts, :events)
    ledger_path = Keyword.fetch!(opts, :ledger)
    driver = Keyword.get(opts, :driver, @default_driver)
    format = Keyword.get(opts, :format, @default_format)

    ensure_directory!(events_path)

    Code.ensure_loaded!(driver)
    Code.ensure_loaded!(format)

    :ets.new(storage_table(instance), [:named_table, :public, :set])
    :ets.insert(storage_table(instance), {:path, events_path})
    :ets.insert(storage_table(instance), {:ledger, ledger_path})
    :ets.insert(storage_table(instance), {:driver, driver})
    :ets.insert(storage_table(instance), {:format, format})

    {:ok, self(), :ignore}
  end

  def write_event(instance, event) do
    config = get_instance_config(instance)
    {record_id, record} = config.driver.prepare_record(event, &config.format.encode/1)
    path = Path.join(config.path, record_id)

    case File.write(path, record, [:exclusive]) do
      :ok ->
        {:ok, record_id}

      {:error, reason} ->
        {:error, reason, record_id}
    end
  end

  def read_event(instance, record_id) do
    record_path = Path.join(path(instance), record_id)
    encoded_event = File.read!(record_path)
    event = format(instance).decode(encoded_event)
    {record_id, event}
  end

  def read_index(instance, index, opts \\ [])

  def read_index(instance, index, opts) when is_list(opts),
    do: read_index(instance, index, Keyword.get(opts, :direction, :forward))

  def read_index(instance, :ledger, direction),
    do: read_index(instance, ledger(instance), direction)

  def read_index(instance, index_file, :backward) do
    if File.exists?(index_file) do
      driver = driver(instance)
      Fact.IndexFileReader.Backwards.Line.read(driver.record_id_length(), index_file)
    else
      empty_stream()
    end
  end

  def read_index(instance, index_file, :forward) do
    if File.exists?(index_file) do
      length = driver(instance).record_id_length()
      File.stream!(index_file) |> Stream.map(&String.slice(&1, 0, length))
    else
      empty_stream()
    end
  end

  def read_index(_instance, _index_file, direction),
    do: raise(ArgumentError, "unknown direction #{inspect(direction)}")

  def read_checkpoint(path) do
    if File.exists?(path) do
      case File.read(path) do
        {:ok, contents} -> contents |> String.trim() |> String.to_integer()
        {:error, _reason} -> 0
      end
    else
      0
    end
  end

  def write_checkpoint(path, position) when is_integer(position) do
    File.write!(path, Integer.to_string(position))
  end

  def write_index(instance, :ledger, record_id),
    do: write_index(instance, ledger(instance), record_id)

  def write_index(instance, index_file, record_id) when is_binary(record_id) do
    write_index(instance, index_file, [record_id])
  end

  def write_index(_instance, index_file, record_ids) when is_list(record_ids) do
    iodata = Enum.reduce(record_ids, [], fn record_id, acc -> [acc, record_id, "\n"] end)
    File.write(index_file, iodata, [:append])
  end

  def line_count(instance, :ledger), do: ledger(instance) |> line_count()

  def line_count(file) do
    if File.exists?(file), do: File.stream!(file) |> Enum.count(), else: 0
  end

  def path(instance) do
    [{:path, path}] = :ets.lookup(storage_table(instance), :path)
    path
  end

  def ledger(instance) do
    [{:ledger, ledger}] = :ets.lookup(storage_table(instance), :ledger)
    ledger
  end

  def driver(instance) do
    [{:driver, driver}] = :ets.lookup(storage_table(instance), :driver)
    driver
  end

  def format(instance) do
    [{:format, format}] = :ets.lookup(storage_table(instance), :format)
    format
  end

  def get_instance_config(instance) do
    %{
      driver: driver(instance),
      format: format(instance),
      path: path(instance)
    }
  end

  def ensure_directory!(path), do: File.mkdir_p!(path)

  def ensure_file!(path, content \\ "") do
    ensure_directory!(Path.dirname(path))
    unless File.exists?(path), do: File.write!(path, to_string(content))
  end

  def ensure_ledger!(instance), do: ensure_file!(ledger(instance))

  defp storage_table(instance), do: :"#{instance}.#{__MODULE__}"
  defp empty_stream(), do: Stream.concat([])
end
