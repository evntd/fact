# defmodule Fact.Storage do
#  @moduledoc """
#  **Internal storage engine for Fact. Do not use directly.**
#
#  This module provides the low-level file-based storage mechanics used by the
#  Fact event store. It handles:
#
#    * creation and management of the storage directory structure
#    * writing and reading raw event records
#    * maintaining event indices and the ledger
#    * managing checkpoint files
#    * tracking storage configuration via ETS
#    * performing backups of the storage directory
#
#  `Fact.Storage` is intentionally low-level and tightly coupled to the internal
#  persistence model. It exposes many functions that operate directly on file
#  paths, indices, and driver/format modules. Because of its internal nature,
#  **it is not considered part of the public API**, and callers should not
#  interact with it directly.
#
#  ### Responsibilities
#
#  `Fact.Storage` is responsible for:
#
#    * Initializing the on-disk directory layout for an instance
#    * Configuring the storage driver and format modules
#    * Writing encoded events to disk
#    * Reading event records and indices
#    * Managing `.checkpoint` files for incremental index consumption
#    * Appending to index files
#    * Resolving storage paths via an ETS table established per instance
#    * Creating and restoring backups of the storage contents
#
#  ### Usage Notes
#
#    * This module is started automatically as part of a Fact instance via
#      its `child_spec/1`.
#    * Direct calls to functions in this module can corrupt storage,
#      break invariants, bypass validation/serialization steps, or result in
#      inconsistent indices.
#    * Only higher-level APIs should be used to interact with events or indexes.
#
#  If you find yourself needing to call this module directly, consider whether
#  there is a missing abstraction or a higher-level API should be extended
#  instead.
#
#  """
#
#  use Fact.Types
#  require Logger
#
#  @type record_id :: String.t()
#  @type hash_algorithm :: :sha | :sha256
#  @type encoding :: :raw | :hash | {:hash, hash_algorithm()}
#
#  def write_events(instance, events) do
#    with write_results <-
#           Task.async_stream(events, &write_event(instance, &1),
#             max_concurrency: System.schedulers_online()
#           ),
#         {:ok, record_ids, []} <- process_write_results(write_results) do
#      {:ok, Enum.reverse(record_ids)}
#    else
#      {:error, _, errors} ->
#        {:error, {:event_write_failed, Enum.reverse(errors)}}
#
#      {:error, reason} ->
#        {:error, reason}
#    end
#  end
#
#  defp process_write_results(results) do
#    Enum.reduce(results, {:ok, [], []}, fn
#      {_, {:ok, record_id}}, {result, records, errors} ->
#        {result, [record_id | records], errors}
#
#      {_, {:error, posix, record_id}}, {_, records, errors} ->
#        {:error, records, [{posix, record_id} | errors]}
#    end)
#  end
#
#  @doc """
#  Writes a single event to disk using the configured driver and format.
#
#  Steps performed:
#    * The storage driver generates a record ID and serialized record contents.
#    * The function attempts an atomic write into the events directory.
#    * On success, it returns `{:ok, record_id}`.
#    * On failure (e.g., duplicate record ID), it returns `{:error, reason, record_id}`.
#  """
#  @spec write_event(atom(), map()) :: {:ok, record_id()} | {:error, term(), record_id()}
#  def write_event(%Fact.Instance{} = instance, event) do
#    inst_driver = Fact.Instance.driver(instance)
#    inst_format = Fact.Instance.format(instance)
#
#    case inst_driver.prepare_record(event, &inst_format.encode/1) do
#      {:error, {reason, record_id}} ->
#        {:error, reason, record_id}
#
#      {:ok, record_id, record} ->
#        record_path = Fact.Instance.record_path(instance, record_id)
#
#        with {:ok, fd} <- File.open(record_path, [:write, :binary, :exclusive]),
#             :ok <- IO.binwrite(fd, record),
#             :ok <- :file.sync(fd),
#             :ok <- File.close(fd) do
#          {:ok, record_id}
#        else
#          {:error, reason} ->
#            {:error, reason, record_id}
#        end
#    end
#  end
#
#  @doc """
#  Reads a single event record from disk and decodes it using the configured format.
#
#  The function:
#    * locates the event file under the events directory
#    * reads the raw encoded event
#    * decodes the event using the configured format module
#    * returns `{record_id, decoded_event}`
#
#  It assumes the record exists and will raise if the underlying file is missing
#  or unreadable.
#  """
#  def read_event!(%Fact.Instance{} = instance, record_id) do
#    record_path = Fact.Instance.record_path(instance, record_id)
#    encoded_event = File.read!(record_path)
#    formatter = Fact.Instance.format(instance)
#    event = formatter.decode(encoded_event)
#    {record_id, event}
#  end
#
#  def read_index(%Fact.Instance{} = instance, indexer, index, opts \\ []) when is_list(opts) do
#    encode_path = Fact.Instance.index_path_encoder(instance, indexer)
#    path = encode_path.(index)
#    driver = Fact.Instance.driver(instance)
#    record_size = driver.record_size()
#
#    read_index_file(
#      path,
#      record_size,
#      Keyword.get(opts, :direction, :forward),
#      Keyword.get(opts, :position, :start),
#      Keyword.get(opts, :count, :all)
#    )
#    |> then(&to_return_type(instance, &1, Keyword.get(opts, :return_type, :event)))
#  end
#
#  def read_index_file(path, record_size, direction, position, count)
#      when is_binary(path) and
#             (is_integer(record_size) and record_size > 0) do
#    with :ok <- valid_direction?(direction),
#         :ok <- valid_position?(position),
#         :ok <- valid_count?(count) do
#      if File.exists?(path) do
#        apply(Fact.IndexFileReader.Line, direction, [path, position, record_size])
#        |> take(count)
#      else
#        empty_stream()
#      end
#    else
#      {:error, :invalid_direction} ->
#        raise Fact.DatabaseError, "invalid read direction: #{direction}"
#
#      {:error, :invalid_position} ->
#        raise Fact.DatabaseError, "invalid read position: #{position}"
#
#      {:error, :invalid_count} ->
#        raise Fact.DatabaseError, "invalid read count: #{count}"
#    end
#  end
#
#  defp take(stream, count) do
#    case count do
#      :all ->
#        stream
#
#      n ->
#        Stream.take(stream, n)
#    end
#  end
#
#  defp to_return_type(instance, stream, return_type) do
#    case return_type do
#      :event ->
#        stream
#        |> Stream.map(&read_event!(instance, &1))
#        |> Stream.map(fn {_, event} -> event end)
#
#      :record ->
#        stream
#        |> Stream.map(&read_event!(instance, &1))
#
#      :record_id ->
#        stream
#
#      _ ->
#        raise Fact.DatabaseError, "invalid return type: #{return_type}"
#    end
#  end
#
#  defp valid_direction?(direction) do
#    cond do
#      direction in [:forward, :backward] ->
#        :ok
#
#      true ->
#        {:error, :invalid_direction}
#    end
#  end
#
#  defp valid_position?(position) do
#    cond do
#      position in [:start, :end] ->
#        :ok
#
#      is_integer(position) and position >= 0 ->
#        :ok
#
#      true ->
#        {:error, :invalid_position}
#    end
#  end
#
#  defp valid_count?(count) do
#    cond do
#      count === :all ->
#        :ok
#
#      is_integer(count) and count >= 0 ->
#        :ok
#
#      true ->
#        {:error, :invalid_count}
#    end
#  end
#
#  def read_ledger(%Fact.Instance{} = instance, opts \\ []) when is_list(opts) do
#    path = Fact.Instance.ledger_path(instance)
#    driver = Fact.Instance.driver(instance)
#    record_size = driver.record_id_length()
#
#    read_index_file(
#      path,
#      record_size,
#      Keyword.get(opts, :direction, :forward),
#      Keyword.get(opts, :position, :start),
#      Keyword.get(opts, :count, :all)
#    )
#    |> then(&to_return_type(instance, &1, Keyword.get(opts, :return_type, :event)))
#  end
#
#  def read_query(%Fact.Instance{} = instance, query, opts \\ [])
#      when is_function(query) and is_list(opts) do
#    {maybe_count, read_ledger_opts} = Keyword.split(opts, [:count])
#
#    predicate = query.(instance)
#
#    read_ledger(instance, [return_type: :record_id] ++ read_ledger_opts)
#    |> Stream.filter(&predicate.(&1))
#    |> take(Keyword.get(maybe_count, :count, :all))
#    |> then(&to_return_type(instance, &1, Keyword.get(opts, :return_type, :event)))
#  end
#
#  def read_checkpoint(%Fact.Instance{} = instance, indexer) do
#    path = Fact.Instance.indexer_checkpoint_path(instance, indexer)
#
#    if File.exists?(path) do
#      case File.read(path) do
#        {:ok, contents} -> contents |> String.trim() |> String.to_integer()
#        {:error, _reason} -> 0
#      end
#    else
#      0
#    end
#  end
#
#  def write_checkpoint(%Fact.Instance{} = instance, indexer, position)
#      when is_integer(position) do
#    path = Fact.Instance.indexer_checkpoint_path(instance, indexer)
#    File.write!(path, Integer.to_string(position))
#  end
#
#  def write_index(%Fact.Instance{} = instance, :ledger, record_ids) do
#    case do_write_index(Fact.Instance.ledger_path(instance), record_ids) do
#      {:ok, records} ->
#        {:ok, records}
#
#      {:error, reason} ->
#        {:error, {:ledger_write_failed, reason}}
#    end
#  end
#
#  def write_index(_instance, _index, nil, _record_id), do: :ignored
#  def write_index(_instance, _index, [], _record_id), do: :ignored
#
#  def write_index(%Fact.Instance{} = instance, index, index_key, record_id)
#      when is_binary(index_key) do
#    encode_path = Fact.Instance.index_path_encoder(instance, index)
#    encoded_path = encode_path.(index_key)
#    do_write_index(encoded_path, record_id)
#  end
#
#  def write_index(%Fact.Instance{} = instance, indexer, index_keys, record_id)
#      when is_list(index_keys) do
#    encode_path = Fact.Instance.index_path_encoder(instance, indexer)
#
#    index_keys
#    |> Enum.uniq()
#    |> Enum.each(&do_write_index(encode_path.(&1), record_id))
#  end
#
#  defp do_write_index(index_file, record_id) when is_binary(record_id) do
#    do_write_index(index_file, [record_id])
#  end
#
#  defp do_write_index(index_file, record_ids) when is_list(record_ids) do
#    iodata = Enum.reduce(record_ids, [], fn record_id, acc -> [acc, record_id, "\n"] end)
#
#    with {:ok, fd} <- File.open(index_file, [:append, :binary]),
#         :ok <- IO.binwrite(fd, iodata),
#         :ok <- :file.sync(fd),
#         :ok <- File.close(fd) do
#      {:ok, record_ids}
#    end
#  end
#
#  @read_last_opts [direction: :backward, position: :end, count: 1, return_type: :event]
#
#  def last_record(%Fact.Instance{} = instance) do
#    read_ledger(instance, @read_last_opts) |> Enum.at(0)
#  end
#
#  def last_record(%Fact.Instance{} = instance, indexer, index) do
#    read_index(instance, indexer, index, @read_last_opts) |> Enum.at(0)
#  end
#
#  def last_store_position(%Fact.Instance{} = instance) do
#    unless is_nil(record = last_record(instance)),
#      do: record[@event_store_position],
#      else: 0
#  end
#
#  def last_store_position(%Fact.Instance{} = instance, indexer, index) do
#    unless is_nil(record = last_record(instance, indexer, index)),
#      do: record[@event_store_position],
#      else: 0
#  end
#
#  def backup(%Fact.Instance{} = instance, backup_path) do
#    database_path = Fact.Instance.database_path(instance)
#
#    events_path =
#      Fact.Instance.events_path(instance) |> String.replace_prefix(database_path <> "/", "")
#
#    ledger_path =
#      Fact.Instance.ledger_path(instance) |> String.replace_prefix(database_path <> "/", "")
#
#    event_entries =
#      read_ledger(instance, :forward)
#      |> Stream.map(&String.to_charlist(Path.join(events_path, &1)))
#      |> Enum.to_list()
#
#    all_entries = [String.to_charlist(ledger_path) | event_entries]
#
#    :zip.create(backup_path, all_entries, [
#      {:compress, :all},
#      {:cwd, String.to_charlist(database_path)}
#    ])
#  end
#
#  defp empty_stream(), do: Stream.concat([])
# end
