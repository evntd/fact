defmodule Fact.Storage do
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
    driver = Keyword.get(opts, :driver, Fact.Storage.Driver.ByEventId)
    format = Keyword.get(opts, :format, Fact.Storage.Format.Json)

    Code.ensure_loaded!(driver)
    Code.ensure_loaded!(format)

    :ets.new(storage_table(instance), [:named_table, :public, :set])
    :ets.insert(storage_table(instance), {:path, path})
    :ets.insert(storage_table(instance), {:driver, driver})
    :ets.insert(storage_table(instance), {:format, format})

    {:ok, self(), :ignore}
  end

  def write_event(instance, event) do
    driver(instance).write_event(path(instance), event)
  end

  def read_event(instance, record_id) do
    record_path = Path.join(path(instance), record_id)
    encoded_event = driver(instance).read_event(record_path)
    event = format(instance).decode(encoded_event)
    {record_id, event}
  end

  def read_index_backward(instance, index_file) do
    driver(instance).read_index_backward(index_file)
  end

  def read_index_forward(instance, index_file) do
    driver(instance).read_index_forward(index_file)
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

  defp storage_table(instance), do: :"#{instance}.#{__MODULE__}"
end
