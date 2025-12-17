defmodule Fact.Storage do
  @moduledoc """
  **Internal storage engine for Fact. Do not use directly.**

  This module provides the low-level file-based storage mechanics used by the
  Fact event store. It handles:

    * creation and management of the storage directory structure
    * writing and reading raw event records
    * maintaining event indices and the ledger
    * managing checkpoint files
    * tracking storage configuration via ETS
    * performing backups of the storage directory

  `Fact.Storage` is intentionally low-level and tightly coupled to the internal
  persistence model. It exposes many functions that operate directly on file
  paths, indices, and driver/format modules. Because of its internal nature,
  **it is not considered part of the public API**, and callers should not
  interact with it directly.

  ### Responsibilities

  `Fact.Storage` is responsible for:

    * Initializing the on-disk directory layout for an instance
    * Configuring the storage driver and format modules
    * Writing encoded events to disk
    * Reading event records and indices
    * Managing `.checkpoint` files for incremental index consumption
    * Appending to index files
    * Resolving storage paths via an ETS table established per instance
    * Creating and restoring backups of the storage contents

  ### Usage Notes

    * This module is started automatically as part of a Fact instance via
      its `child_spec/1`.
    * Direct calls to functions in this module can corrupt storage,
      break invariants, bypass validation/serialization steps, or result in
      inconsistent indices.
    * Only higher-level APIs should be used to interact with events or indexes.

  If you find yourself needing to call this module directly, consider whether
  there is a missing abstraction or a higher-level API should be extended
  instead.

  """

  use Fact.EventKeys
  require Logger

  @type record_id :: String.t()
  @type hash_algorithm :: :sha | :sha256
  @type encoding :: :raw | :hash | {:hash, hash_algorithm()}

  @index_checkpoint ".checkpoint"

  @doc """
  Returns the child specification for a `Fact.Storage` instance.

  This is an internal function used by `Fact.Supervisor` and related startup
  infrastructure. It constructs a unique child ID based on the `:instance` value
  and wires the process to start via `start_link/1`.
  """
  def child_spec(opts) do
    %{
      id: {__MODULE__, Keyword.fetch!(opts, :instance)},
      start: {__MODULE__, :start_link, [opts]},
      type: :worker
    }
  end

  @doc """
  Initializes and starts the storage engine for a Fact instance.

  This function is responsible for:
    * normalizing and preparing the on-disk storage directory
    * loading the configured storage driver and event format modules
    * creating the events directory and a `.gitignore`
    * initializing the ETS metadata table used by all subsequent operations

  The function completes setup and returns `{:ok, pid, :ignore}` to avoid
  linking semantics used by other OTP behaviors.
  """
  def start_link(opts) do
    instance = Keyword.fetch!(opts, :instance)
    setup_table(instance)
    {:ok, self()}
  end

  @doc """
  Ensures that the directory structure and checkpoint file for a given index exist.

  This function:
    * computes the fully qualified path for the index and its checkpoint file
    * creates directories and writes a default `.checkpoint` file if missing
    * stores index metadata (paths and encoders) in the storage ETS table

  The `encoding` argument determines how index keys are mapped into filenames,
  which is handled via `encode_key/2`.
  """
  @spec ensure_index(atom(), term(), encoding()) :: :ok
  def ensure_index(instance, index, encoding) do
    index_path =
      case index do
        {index_module, index_module_key} ->
          Path.join([
            Fact.Instance.indices_path(instance),
            to_string(index_module),
            to_string(index_module_key)
          ])

        index_module ->
          Path.join([Fact.Instance.indices_path(instance), to_string(index_module)])
      end

    checkpoint_path = Path.join(index_path, @index_checkpoint)

    with :ok <- ensure_file(checkpoint_path, 0) do
      table = Fact.Instance.storage_table(instance)
      :ets.insert(table, {{index, :index_path}, index_path})
      :ets.insert(table, {{index, :index_checkpoint_path}, checkpoint_path})
      :ets.insert(table, {{index, :index_path_encoder}, index_path_encoder(index_path, encoding)})
      :ok
    end
  end

  @doc """
  Ensures that the ledger file exists on disk.

  The ledger is the global, append-only index of all events written for a Fact
  instance. If the ledger file does not exist, this function creates it.
  """
  @spec ensure_ledger(atom()) ::
          :ok | {:error, File.posix() | :badarg | :terminated | :system_limit}
  def ensure_ledger(instance) do
    ensure_file(ledger_path(instance))
  end

  defp ensure_directory(path) do
    File.mkdir_p(path)
  end

  defp ensure_file(path, content \\ "") do
    with :ok <- ensure_directory(Path.dirname(path)) do
      unless File.exists?(path),
        do: File.write(path, to_string(content)),
        else: :ok
    end
  end

  @doc """
  Writes a single event to disk using the configured driver and format.

  Steps performed:
    * The storage driver generates a record ID and serialized record contents.
    * The function attempts an atomic write into the events directory.
    * On success, it returns `{:ok, record_id}`.
    * On failure (e.g., duplicate record ID), it returns `{:error, reason, record_id}`.
  """
  @spec write_event(atom(), map()) :: {:ok, record_id()} | {:error, term(), record_id()}
  def write_event(instance, event) do
    inst_driver = driver(instance)
    inst_format = format(instance)
    inst_path = events_path(instance)

    case inst_driver.prepare_record(event, &inst_format.encode/1) do
      {:error, {reason, record_id}} ->
        {:error, reason, record_id}

      {:ok, record_id, record} ->
        record_path = Path.join(inst_path, record_id)

        case File.write(record_path, record, [:exclusive]) do
          :ok ->
            {:ok, record_id}

          {:error, reason} ->
            {:error, reason, record_id}
        end
    end
  end

  defp get_index_path_encoder(instance, index) do
    [{{^index, :index_path_encoder}, path_encoder}] =
      :ets.lookup(Fact.Instance.storage_table(instance), {index, :index_path_encoder})

    path_encoder
  end

  defp get_checkpoint_path(instance, index) do
    [{{^index, :index_checkpoint_path}, checkpoint_path}] =
      :ets.lookup(Fact.Instance.storage_table(instance), {index, :index_checkpoint_path})

    checkpoint_path
  end

  defp index_path_encoder(path, encoding) do
    fn key -> Path.join(path, encode_key(key, encoding)) end
  end

  @doc """
  Reads a single event record from disk and decodes it using the configured format.

  The function:
    * locates the event file under the events directory
    * reads the raw encoded event
    * decodes the event using the configured format module
    * returns `{record_id, decoded_event}`

  It assumes the record exists and will raise if the underlying file is missing
  or unreadable.
  """
  def read_event!(instance, record_id) do
    record_path = Path.join(events_path(instance), record_id)
    encoded_event = File.read!(record_path)
    event = format(instance).decode(encoded_event)
    {record_id, event}
  end

  def read_ledger(instance, direction),
    do: read_index_file(instance, ledger_path(instance), direction)

  def read_index(instance, indexer, index, direction) do
    encode_path = get_index_path_encoder(instance, indexer)
    encoded_path = encode_path.(index)
    read_index_file(instance, encoded_path, direction)
  end

  defp read_index_file(instance, path, :backward) do
    if File.exists?(path) do
      driver = driver(instance)
      Fact.IndexFileReader.Backwards.Line.read(driver.record_id_length(), path)
    else
      empty_stream()
    end
  end

  defp read_index_file(instance, path, :forward) do
    if File.exists?(path) do
      length = driver(instance).record_id_length()
      File.stream!(path) |> Stream.map(&String.slice(&1, 0, length))
    else
      empty_stream()
    end
  end

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
    do: do_write_index(ledger_path(instance), record_id)

  def write_index(_instance, _index, nil, _record_id), do: :ignored
  def write_index(_instance, _index, [], _record_id), do: :ignored

  def write_index(instance, index, index_key, record_id) when is_binary(index_key) do
    encode_path = get_index_path_encoder(instance, index)
    encoded_path = encode_path.(index_key)
    do_write_index(encoded_path, record_id)
  end

  def write_index(instance, index, index_keys, record_id) when is_list(index_keys) do
    encode_path = get_index_path_encoder(instance, index)

    index_keys
    |> Enum.uniq()
    |> Enum.each(&do_write_index(encode_path.(&1), record_id))
  end

  defp do_write_index(index_file, record_id) when is_binary(record_id) do
    do_write_index(index_file, [record_id])
  end

  defp do_write_index(index_file, record_ids) when is_list(record_ids) do
    iodata = Enum.reduce(record_ids, [], fn record_id, acc -> [acc, record_id, "\n"] end)
    File.write(index_file, iodata, [:append])
  end

  def last_store_position(instance, indexer, index) do
    do_last_store_position(instance, read_index(instance, indexer, index, direction: :backward))
  end

  def last_store_position(instance, :ledger) do
    do_last_store_position(instance, read_ledger(instance, :backward))
  end

  defp do_last_store_position(instance, stream) do
    last_record_id = stream |> Enum.at(0, :none)

    case last_record_id do
      :none ->
        0

      record_id ->
        {_, event} = read_event!(instance, record_id)
        event[@event_store_position]
    end
  end

  def backup(instance, backup_path) do
    storage_path = path(instance)
    events_path = events_path(instance) |> String.replace_prefix(storage_path <> "/", "")
    ledger_path = ledger_path(instance) |> String.replace_prefix(storage_path <> "/", "")

    event_entries =
      read_ledger(instance, :forward)
      |> Stream.map(&String.to_charlist(Path.join(events_path, &1)))
      |> Enum.to_list()

    all_entries = [String.to_charlist(ledger_path) | event_entries]

    :zip.create(backup_path, all_entries, [
      {:compress, :all},
      {:cwd, String.to_charlist(storage_path)}
    ])
  end

  def path(instance) do
    [{:path, path}] = :ets.lookup(Fact.Instance.storage_table(instance), :path)
    path
  end

  def events_path(instance) do
    [{:events_path, events_path}] =
      :ets.lookup(Fact.Instance.storage_table(instance), :events_path)

    events_path
  end

  def indices_path(instance) do
    [{:indices_path, indices_path}] =
      :ets.lookup(Fact.Instance.storage_table(instance), :indices_path)

    indices_path
  end

  def ledger_path(instance) do
    [{:ledger_path, ledger_path}] =
      :ets.lookup(Fact.Instance.storage_table(instance), :ledger_path)

    ledger_path
  end

  def driver(instance) do
    [{:driver, driver_module}] = :ets.lookup(Fact.Instance.storage_table(instance), :driver)
    driver_module
  end

  def format(instance) do
    [{:format, format_module}] = :ets.lookup(Fact.Instance.storage_table(instance), :format)
    format_module
  end

  defp encode_key(value, :raw), do: to_string(value)
  defp encode_key(value, :hash), do: encode_key(value, {:hash, :sha})

  defp encode_key(value, {:hash, algo}),
    do: :crypto.hash(algo, to_string(value)) |> Base.encode16(case: :lower)

  defp encode_key(_value, encoding),
    do: raise(ArgumentError, "unsupported encoding: #{inspect(encoding)}")

  defp setup_table(instance) do
    # TODO: Remove these driver/format dependencies!
    with {:module, _driver_module} <- Code.ensure_loaded(instance.manifest.records.old_driver),
         {:module, _format_module} <- Code.ensure_loaded(instance.manifest.records.old_format) do
      table = Fact.Instance.storage_table(instance)
      :ets.new(table, [:named_table, :public, :set])
      :ets.insert(table, {:path, Fact.Instance.database_path(instance)})
      :ets.insert(table, {:events_path, Fact.Instance.events_path(instance)})
      :ets.insert(table, {:ledger_path, Fact.Instance.ledger_path(instance)})
      :ets.insert(table, {:indices_path, Fact.Instance.indices_path(instance)})
      :ets.insert(table, {:driver, instance.manifest.records.old_driver})
      :ets.insert(table, {:format, instance.manifest.records.old_format})
    end
  end

  defp empty_stream(), do: Stream.concat([])
end
