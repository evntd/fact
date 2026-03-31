defmodule Fact.WriteAheadLog do
  @moduledoc """
  A segmented, append-only write-ahead log for durability and crash recovery.

  `Fact.WriteAheadLog` records every event write as a binary entry before it is committed to the
  ledger and indexes. On crash, the `Fact.EventLedger` replays uncommitted WAL entries to restore
  the database to a consistent state.

  The WAL is organized as a series of numbered segment files. When the active segment exceeds
  `:max_file_size`, it is rotated and a new segment is opened. Old segments beyond `:max_segments`
  are deleted automatically.

  Checkpoint entries can be written to mark a known-good recovery point. During recovery, replay
  begins from the most recent checkpoint rather than scanning the entire log.

  A periodic sync timer flushes the write buffer to disk at the configured `:sync_interval`.
  When `:enable_fsync` is `true`, each sync calls `fsync` to guarantee durability.

  This process is started and supervised by `Fact.DatabaseSupervisor` and is not intended to be
  started directly. Configuration options can be passed through `Fact.open/2` via the `:wal` key.

  ## Configuration

  See `t:wal_option/0` for available options and their defaults.
  """
  @moduledoc since: "0.3.0"
  use GenServer

  alias Fact.WriteAheadLog
  alias Fact.WriteAheadLog.Entry

  @typedoc """
  Write-ahead log configuration options.

    * `:enable_fsync` - Whether to call fsync after writes. Defaults to `true`.
    * `:max_file_size` - Maximum size in bytes of a WAL segment file before rotation. Defaults to `16_777_216` (16 MB).
    * `:max_segments` - Maximum number of segment files to retain. Defaults to `4`.
    * `:sync_interval` - Time in milliseconds between periodic sync operations. Defaults to `200`. Values below `10` are clamped to `10` to prevent mailbox flooding.
  """
  @typedoc since: "0.3.0"
  @type wal_option ::
          {:enable_fsync, boolean()}
          | {:max_file_size, pos_integer()}
          | {:max_segments, pos_integer()}
          | {:sync_interval, pos_integer()}

  @typedoc """
  Options accepted by `start_link/1`.

    * `:database_id` - (required) The database identifier used to scope the WAL directory and process registration.
    * `:name` - (required) The registered process name, typically constructed via `Fact.Registry.via/2`.
    * `:enable_fsync` - See `t:wal_option/0`.
    * `:max_file_size` - See `t:wal_option/0`.
    * `:max_segments` - See `t:wal_option/0`.
    * `:sync_interval` - See `t:wal_option/0`.
  """
  @typedoc since: "0.3.0"
  @type option ::
          {:database_id, Fact.database_id()}
          | {:name, GenServer.name()}
          | wal_option()

  # -----------------------------
  # Public API
  # -----------------------------

  @doc """
  Starts a `Fact.WriteAheadLog` process linked to the calling process.

  Requires `:database_id` and `:name` in `opts`. Additional `t:wal_option/0` keys are optional.
  """
  @doc since: "0.3.0"
  @spec start_link([option()]) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  @doc """
  Appends a binary entry to the write-ahead log.

  The entry is written to the active segment file. If the segment exceeds `:max_file_size`,
  a rotation occurs before the write.
  """
  @doc since: "0.3.0"
  @spec write_entry(Fact.database_id(), binary()) :: :ok | {:error, term()}
  def write_entry(database_id, data),
    do: GenServer.call(Fact.Registry.via(database_id, WriteAheadLog), {:write_entry, data, false})

  @doc """
  Writes a checkpoint entry to the write-ahead log.

  A checkpoint marks a known-good recovery point. During crash recovery, replay begins from
  the most recent checkpoint rather than the beginning of the log. The buffer is flushed
  to disk immediately after a checkpoint is written.
  """
  @doc since: "0.3.0"
  @spec create_checkpoint(Fact.database_id(), binary()) :: :ok | {:error, term()}
  def create_checkpoint(database_id, data),
    do: GenServer.call(Fact.Registry.via(database_id, WriteAheadLog), {:write_entry, data, true})

  @doc """
  Flushes the write buffer to disk.
  """
  @doc since: "0.3.0"
  @spec sync(Fact.database_id()) :: :ok
  def sync(database_id),
    do: GenServer.call(Fact.Registry.via(database_id, WriteAheadLog), :sync)

  @doc """
  Flushes the write buffer and closes the active segment file.
  """
  @doc since: "0.3.0"
  @spec close(Fact.database_id()) :: :ok
  def close(database_id),
    do: GenServer.call(Fact.Registry.via(database_id, WriteAheadLog), :close)

  @doc """
  Reads all entries from every segment in the write-ahead log.

  When `from_checkpoint?` is `true`, only entries written after the most recent checkpoint
  are returned. When `false`, all entries across all segments are returned in order.
  """
  @doc since: "0.3.0"
  @spec read_all(Fact.database_id(), boolean()) :: [Entry.t()]
  def read_all(database_id, from_checkpoint? \\ false),
    do:
      GenServer.call(Fact.Registry.via(database_id, WriteAheadLog), {:read_all, from_checkpoint?})

  @doc """
  Reads entries from segments at or after the given segment `offset`.

  Behaves like `read_all/2` but skips segments with an index lower than `offset`.
  """
  @doc since: "0.3.0"
  @spec read_all_from_offset(Fact.database_id(), non_neg_integer(), boolean()) :: [Entry.t()]
  def read_all_from_offset(database_id, offset, from_checkpoint? \\ false),
    do:
      GenServer.call(
        Fact.Registry.via(database_id, WriteAheadLog),
        {:read_all_from_offset, offset, from_checkpoint?}
      )

  @doc """
  Repairs the most recent WAL segment by discarding corrupt trailing entries.

  Reads the newest segment file entry-by-entry. Valid entries (those that pass CRC verification)
  are kept; the first corrupt entry and everything after it are discarded. The repaired segment
  is written back to disk in place.
  """
  @doc since: "0.3.0"
  @spec repair(Fact.database_id()) :: {:ok, list()} | {:error, :no_segments}
  def repair(database_id),
    do: GenServer.call(Fact.Registry.via(database_id, WriteAheadLog), :repair)

  # -----------------------------
  # State Fields
  # -----------------------------
  defstruct database_id: nil,
            file: nil,
            buffer: nil,
            last_seq: 0,
            segment_index: 0,
            max_file_size: nil,
            max_segments: nil,
            should_fsync: false,
            sync_interval: 0

  # -----------------------------
  # Init
  # -----------------------------
  @default_enable_fsync true
  @default_max_file_size 16 * 1024 * 1024
  @default_max_segments 4
  @default_sync_interval 200
  @min_sync_interval 10

  @impl true
  def init(opts) do
    database_id = Keyword.fetch!(opts, :database_id)
    enable_fsync = Keyword.get(opts, :enable_fsync, @default_enable_fsync)
    max_file_size = Keyword.get(opts, :max_file_size, @default_max_file_size)
    max_segments = Keyword.get(opts, :max_segments, @default_max_segments)

    sync_interval =
      Keyword.get(opts, :sync_interval, @default_sync_interval) |> max(@min_sync_interval)

    directory = Fact.Storage.write_ahead_log_path(database_id)
    File.mkdir_p!(directory)

    segment_index =
      segment_files(database_id)
      |> last_segment_index()

    # `file` stores the path; `buffer` is the IO device used for writing
    file = segment_path(database_id, segment_index)
    {:ok, buffer} = :file.open(file, [:append, :binary, :read, :write])

    state = %__MODULE__{
      database_id: database_id,
      file: file,
      buffer: buffer,
      segment_index: segment_index,
      max_file_size: max_file_size,
      max_segments: max_segments,
      should_fsync: enable_fsync,
      sync_interval: sync_interval
    }

    last_seq = get_last_sequence_no(state)

    Process.send_after(self(), :sync_tick, sync_interval)

    {:ok, %{state | last_seq: last_seq}}
  end

  # -----------------------------
  # Handle Calls
  # -----------------------------
  @impl true
  def handle_call({:write_entry, data, checkpoint?}, _from, state) do
    case maybe_rotate(state) do
      {:error, e} ->
        {:reply, {:error, e}, state}

      {:ok, state} ->
        seq = state.last_seq + 1
        entry = Entry.create(seq, data, checkpoint?)
        {:ok, state} = write_entry_to_buffer(entry, %{state | last_seq: seq})

        state =
          if checkpoint? do
            {:ok, st} = sync_impl(state)
            st
          else
            state
          end

        {:reply, :ok, state}
    end
  end

  def handle_call(:sync, _from, state) do
    {:ok, state} = sync_impl(state)
    {:reply, :ok, state}
  end

  def handle_call(:close, _from, state) do
    {:ok, _} = sync_impl(state)
    :file.close(state.buffer)
    {:reply, :ok, state}
  end

  def handle_call({:read_all, from_checkpoint?}, _from, state) do
    files = segment_files(state.database_id) |> Enum.sort()
    {:reply, read_segments(files, from_checkpoint?), state}
  end

  def handle_call({:read_all_from_offset, offset, from_checkpoint?}, _from, state) do
    files =
      segment_files(state.database_id)
      |> Enum.filter(fn {idx, _} -> idx >= offset end)
      |> Enum.sort()

    {:reply, read_segments(files, from_checkpoint?), state}
  end

  def handle_call(:repair, _from, state) do
    files = segment_files(state.database_id)

    case Enum.max_by(files, fn {idx, _} -> idx end, fn -> {0, nil} end) do
      {_, path} ->
        {:reply, repair_segment(path), state}

      _ ->
        {:reply, {:error, :no_segments}, state}
    end
  end

  # -----------------------------
  # Periodic sync
  # -----------------------------
  @impl true
  def handle_info(:sync_tick, %{sync_interval: sync_interval} = state) do
    {:ok, state} = sync_impl(state)
    Process.send_after(self(), :sync_tick, sync_interval)
    {:noreply, state}
  end

  # -----------------------------
  # Helpers
  # -----------------------------

  defp segment_path(database_id, idx) do
    dir = Fact.Storage.write_ahead_log_path(database_id)
    Path.join(dir, "#{idx}")
  end

  defp segment_files(database_id) do
    dir = Fact.Storage.write_ahead_log_path(database_id)

    Path.wildcard(Path.join(dir, "*"))
    |> Enum.flat_map(fn file ->
      case Integer.parse(Path.basename(file)) do
        {idx, ""} -> [{idx, file}]
        _ -> []
      end
    end)
  end

  defp last_segment_index([]), do: 0
  defp last_segment_index(files), do: files |> Enum.max_by(&elem(&1, 0)) |> elem(0)

  defp file_size(file) do
    File.stat!(file).size
  end

  defp maybe_rotate(state) do
    size = file_size(state.file)

    if size >= state.max_file_size do
      rotate(state)
    else
      {:ok, state}
    end
  end

  defp rotate(state) do
    {:ok, state} = sync_impl(state)
    :file.close(state.buffer)

    next_index = state.segment_index + 1

    if length(segment_files(state.database_id)) >= state.max_segments do
      delete_oldest_segment(state)
    end

    file = segment_path(state.database_id, next_index)

    case :file.open(file, [:append, :binary, :read, :write]) do
      {:ok, buffer} -> {:ok, %{state | segment_index: next_index, file: file, buffer: buffer}}
      {:error, _} = err -> err
    end
  end

  defp delete_oldest_segment(state) do
    [{_, path} | _] =
      segment_files(state.database_id)
      |> Enum.sort()

    File.rm(path)
  end

  defp write_entry_to_buffer(entry, state) do
    bin = Entry.serialize(entry)
    size = byte_size(bin)

    :ok = :file.write(state.buffer, <<size::little-32>>)
    :ok = :file.write(state.buffer, bin)
    {:ok, state}
  end

  defp sync_impl(state) do
    if state.should_fsync, do: :file.sync(state.buffer)
    {:ok, state}
  end

  # ---------------------
  # Reading
  # ---------------------

  defp read_segments(files, from_checkpoint?) do
    Enum.reduce(files, {[], 0}, fn {_idx, path}, {acc, last_cp} ->
      {:ok, fd} = File.open(path, [:read, :binary])
      {entries, cp} = do_read_entries(fd, from_checkpoint?)
      File.close(fd)

      if from_checkpoint? and cp > last_cp do
        {entries, cp}
      else
        {acc ++ entries, last_cp}
      end
    end)
    |> elem(0)
  end

  defp do_read_entries(fd, from_checkpoint?) do
    read_loop(fd, [], 0, from_checkpoint?)
  end

  defp read_loop(fd, acc, last_cp, from_checkpoint?) do
    case :file.read(fd, 4) do
      {:ok, <<size::little-32>>} ->
        case :file.read(fd, size) do
          {:ok, bin} ->
            case Entry.deserialize(bin) do
              {:ok, entry} ->
                {new_acc, new_cp} =
                  if entry.is_checkpoint and from_checkpoint? do
                    {[], entry.lsn}
                  else
                    {[entry | acc], last_cp}
                  end

                read_loop(fd, new_acc, new_cp, from_checkpoint?)

              {:error, _} ->
                {Enum.reverse(acc), last_cp}
            end

          :eof ->
            {Enum.reverse(acc), last_cp}

          {:error, _} = err ->
            err
        end

      :eof ->
        {Enum.reverse(acc), last_cp}

      {:error, _} = err ->
        err
    end
  end

  # ---------------------
  # Repair
  # ---------------------

  defp repair_segment(path) do
    {:ok, fd} = File.open(path, [:read, :binary])

    fixed =
      Stream.unfold(:ok, fn
        :ok ->
          case :file.read(fd, 4) do
            {:ok, <<size::little-32>>} ->
              case :file.read(fd, size) do
                {:ok, bin} ->
                  case Entry.deserialize(bin) do
                    {:ok, _entry} -> {{byte_size(bin), bin}, :ok}
                    {:error, _} -> nil
                  end

                _ ->
                  nil
              end

            _ ->
              nil
          end

        _ ->
          nil
      end)
      |> Enum.to_list()

    File.close(fd)

    {:ok, out} = File.open(path, [:write, :binary])

    Enum.each(fixed, fn {size, bin} ->
      :file.write(out, <<size::little-32>>)
      :file.write(out, bin)
    end)

    File.close(out)

    {:ok, fixed}
  end

  # ---------------------
  # Last sequence
  # ---------------------

  defp get_last_sequence_no(state) do
    {:ok, fd} = File.open(state.file, [:read, :binary])
    seq = read_last_entry_seq(fd, 0)
    File.close(fd)
    seq
  end

  defp read_last_entry_seq(fd, prev_seq) do
    case :file.read(fd, 4) do
      {:ok, <<size::little-32>>} ->
        case :file.read(fd, size) do
          {:ok, bin} ->
            case Entry.deserialize(bin) do
              {:ok, entry} -> read_last_entry_seq(fd, entry.lsn)
              {:error, _} -> prev_seq
            end

          _ ->
            prev_seq
        end

      :eof ->
        prev_seq

      _ ->
        prev_seq
    end
  end
end
