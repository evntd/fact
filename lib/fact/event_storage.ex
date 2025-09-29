defmodule Fact.EventStorage do
  @moduledoc false

  def child_spec(opts) do
    %{
      id: {__MODULE__, Keyword.fetch!(opts, :instance)},
      start: {__MODULE__, :start_link, [opts]},
      type: :worker
    }
  end

  def start_link(opts) do
    instance = Keyword.fetch!(opts, :instance)
    path = Keyword.fetch!(opts, :path)
    driver = Keyword.get(opts, :driver, Fact.EventStorage.Driver.ByEventId)
    format = Keyword.get(opts, :format, Fact.EventStorage.Format.Json)

    ensure_path!(path)

    Code.ensure_loaded!(driver)
    Code.ensure_loaded!(format)

    :ets.new(storage_table(instance), [:named_table, :public, :set])
    :ets.insert(storage_table(instance), {:path, path})
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

  def read_index_backward(instance, index_file) do
    driver = driver(instance)
    Fact.IndexFileReader.Backwards.Line.read(driver.record_id_length(), index_file)
  end

  def read_index_forward(instance, index_file) do
    length = driver(instance).record_id_length()
    File.stream!(index_file) |> Stream.map(&String.slice(&1, 0, length))
  end

  def path(instance) do
    [{:path, path}] = :ets.lookup(storage_table(instance), :path)
    path
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

  defp storage_table(instance), do: :"#{instance}.#{__MODULE__}"

  defp ensure_path!(path), do: File.mkdir_p!(path)
end
