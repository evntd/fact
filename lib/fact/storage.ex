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

    path = Keyword.get(opts, :path, Path.join(".fact", normalize(instance)))
    driver = Keyword.get(opts, :driver, @default_driver)
    format = Keyword.get(opts, :format, @default_format)

    events_path = Path.join(path, "events")
    ledger_path = Path.join(path, "ledger")
    indices_path = Path.join(path, "indices")

    ensure_directory!(events_path)

    Code.ensure_loaded!(driver)
    Code.ensure_loaded!(format)

    table = storage_table(instance)
    :ets.new(table, [:named_table, :public, :set])
    :ets.insert(table, {:events_path, events_path})
    :ets.insert(table, {:ledger_path, ledger_path})
    :ets.insert(table, {:indices_path, indices_path})
    :ets.insert(table, {:driver, driver})
    :ets.insert(table, {:format, format})

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

  defp get_index_path_encoder(instance, index) do
    [{{^index, :index_path_encoder}, path_encoder}] =
      :ets.lookup(storage_table(instance), {index, :index_path_encoder})

    path_encoder
  end

  defp get_checkpoint_path(instance, index) do
    [{{^index, :index_checkpoint_path}, checkpoint_path}] =
      :ets.lookup(storage_table(instance), {index, :index_checkpoint_path})

    checkpoint_path
  end

  defp index_path_encoder(path, encoding) do
    fn key -> Path.join(path, encode_key(key, encoding)) end
  end

  defp encode_key(value, :raw), do: to_string(value)
  defp encode_key(value, :hash), do: encode_key(value, {:hash, :sha})

  defp encode_key(value, {:hash, algo}),
    do: :crypto.hash(algo, to_string(value)) |> Base.encode16(case: :lower)

  defp encode_key(_value, encoding),
    do: raise(ArgumentError, "unsupported encoding: #{inspect(encoding)}")

  def read_event(instance, record_id) do
    record_path = Path.join(path(instance), record_id)
    encoded_event = File.read!(record_path)
    event = format(instance).decode(encoded_event)
    {record_id, event}
  end

  def read_index(instance, index, key, opts) do
    encode_path = get_index_path_encoder(instance, index)
    encoded_path = encode_path.(key)
    read_index(instance, encoded_path, Keyword.get(opts, :direction, :forward))
  end

  def read_index(instance, index, opts) when is_list(opts),
    do: read_index(instance, index, Keyword.get(opts, :direction, :forward))

  def read_index(instance, :ledger, direction),
    do: read_index(instance, ledger_path(instance), direction)

  def read_index(instance, path, :backward) do
    if File.exists?(path) do
      driver = driver(instance)
      Fact.IndexFileReader.Backwards.Line.read(driver.record_id_length(), path)
    else
      empty_stream()
    end
  end

  def read_index(instance, path, :forward) do
    if File.exists?(path) do
      length = driver(instance).record_id_length()
      File.stream!(path) |> Stream.map(&String.slice(&1, 0, length))
    else
      empty_stream()
    end
  end

  def read_index(_instance, _path, direction),
    do: raise(ArgumentError, "unknown direction #{inspect(direction)}")

  def read_checkpoint(instance, index) do
    path = get_checkpoint_path(instance, index)

    if File.exists?(path) do
      case File.read(path) do
        {:ok, contents} -> contents |> String.trim() |> String.to_integer()
        {:error, _reason} -> 0
      end
    else
      0
    end
  end

  def write_checkpoint(instance, index, position) when is_integer(position) do
    path = get_checkpoint_path(instance, index)
    File.write!(path, Integer.to_string(position))
  end

  def write_index(instance, :ledger, record_id),
    do: write_index(ledger_path(instance), record_id)

  def write_index(_instance, _index, nil, _record_id), do: :ignored
  def write_index(_instance, _index, [], _record_id), do: :ignored

  def write_index(instance, index, index_key, record_id) when is_binary(index_key) do
    encode_path = get_index_path_encoder(instance, index)
    encoded_path = encode_path.(index_key)
    write_index(encoded_path, record_id)
  end

  def write_index(instance, index, index_keys, record_id) when is_list(index_keys) do
    encode_path = get_index_path_encoder(instance, index)

    index_keys
    |> Enum.each(&write_index(encode_path.(&1), record_id))
  end

  def write_index(index_file, record_id) when is_binary(record_id) do
    write_index(index_file, [record_id])
  end

  def write_index(index_file, record_ids) when is_list(record_ids) do
    iodata = Enum.reduce(record_ids, [], fn record_id, acc -> [acc, record_id, "\n"] end)
    File.write(index_file, iodata, [:append])
  end

  def line_count(instance, :ledger), do: ledger_path(instance) |> line_count()

  def line_count(instance, index, key) do
    encode_path = get_index_path_encoder(instance, index)
    encoded_path = encode_path.(key)
    line_count(encoded_path)
  end

  def line_count(file) do
    if File.exists?(file), do: File.stream!(file) |> Enum.count(), else: 0
  end

  def path(instance) do
    [{:events_path, path}] = :ets.lookup(storage_table(instance), :events_path)
    path
  end

  def indices_path(instance) do
    [{:indices_path, path}] = :ets.lookup(storage_table(instance), :indices_path)
    path
  end

  def ledger_path(instance) do
    [{:ledger_path, ledger}] = :ets.lookup(storage_table(instance), :ledger_path)
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

  def ensure_index!(instance, index, encoding) do
    index_path =
      case index do
        {index_module, index_module_key} ->
          Path.join([
            indices_path(instance),
            to_string(index_module),
            to_string(index_module_key)
          ])

        index_module ->
          Path.join([indices_path(instance), to_string(index_module)])
      end

    checkpoint_path = Path.join(index_path, ".checkpoint")

    ensure_directory!(index_path)
    ensure_file!(checkpoint_path, 0)

    table = storage_table(instance)
    :ets.insert(table, {{index, :index_path}, index_path})
    :ets.insert(table, {{index, :index_checkpoint_path}, checkpoint_path})
    :ets.insert(table, {{index, :index_path_encoder}, index_path_encoder(index_path, encoding)})
  end

  def ensure_ledger!(instance), do: ensure_file!(ledger_path(instance))

  defp storage_table(instance), do: :"#{instance}.#{__MODULE__}"
  defp empty_stream(), do: Stream.concat([])

  defp normalize(name) do
    to_string(name)
    |> String.replace_prefix("Elixir.", "")
    |> String.replace("/", "_")
    |> String.downcase()
  end
end
