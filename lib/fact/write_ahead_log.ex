defmodule Fact.WriteAheadLog do
  use GenServer

  @sync_interval 200
  @segment_prefix "segment-"

  alias __MODULE__.Entry

  # -----------------------------
  # Public API
  # -----------------------------

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  def write_entry(pid, data),
      do: GenServer.call(pid, {:write_entry, data, false})

  def create_checkpoint(pid, data),
      do: GenServer.call(pid, {:write_entry, data, true})

  def sync(pid),
      do: GenServer.call(pid, :sync)

  def close(pid),
      do: GenServer.call(pid, :close)

  def read_all(pid, from_checkpoint? \\ false),
      do: GenServer.call(pid, {:read_all, from_checkpoint?})

  def read_all_from_offset(pid, offset, from_checkpoint? \\ false),
      do: GenServer.call(pid, {:read_all_from_offset, offset, from_checkpoint?})

  def repair(pid),
      do: GenServer.call(pid, :repair)

  # -----------------------------
  # State Fields
  # -----------------------------
  defstruct directory: nil,
            file: nil,
            buf: nil,
            last_seq: 0,
            segment_index: 0,
            max_file_size: nil,
            max_segments: nil,
            should_fsync: false,
            sync_ref: nil

  # -----------------------------
  # Init
  # -----------------------------
  @default_enable_fsync true
  @default_max_file_size 16 * 1024 * 1024
  @default_max_segments 100

  @impl true
  def init(opts) do
    directory = opts[:directory]
    enable_fsync = Keyword.get(opts, :enable_fsync, @default_enable_fsync)
    max_file_size = Keyword.get(opts, :max_file_size, @default_max_file_size)
    max_segments = Keyword.get(opts, :max_segments, @default_max_segments)

    File.mkdir_p!(directory)

    segment_index =
      directory
      |> segment_files()
      |> last_segment_index()

    # `file` stores the path; `buf` is the IO device used for writing
    file = segment_path(directory, segment_index)
    {:ok, buf} = :file.open(file, [:append, :binary, :read, :write])

    state = %__MODULE__{
      directory: directory,
      file: file,
      buf: buf,
      segment_index: segment_index,
      max_file_size: max_file_size,
      max_segments: max_segments,
      should_fsync: enable_fsync
    }

    last_seq = get_last_sequence_no(state)

    Process.send_after(self(), :sync_tick, @sync_interval)

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
    :file.close(state.buf)
    {:reply, :ok, state}
  end

  def handle_call({:read_all, from_checkpoint?}, _from, state) do
    files = state.directory |> segment_files() |> Enum.sort()
    {:reply, read_segments(files, from_checkpoint?), state}
  end

  def handle_call({:read_all_from_offset, offset, from_checkpoint?}, _from, state) do
    files =
      state.directory
      |> segment_files()
      |> Enum.filter(fn {idx, _} -> idx >= offset end)
      |> Enum.sort()

    {:reply, read_segments(files, from_checkpoint?), state}
  end

  def handle_call(:repair, _from, state) do
    files = segment_files(state.directory)

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
  def handle_info(:sync_tick, state) do
    {:ok, state} = sync_impl(state)
    Process.send_after(self(), :sync_tick, @sync_interval)
    {:noreply, state}
  end

  # -----------------------------
  # Helpers
  # -----------------------------

  defp segment_path(dir, idx), do: Path.join(dir, "#{@segment_prefix}#{idx}")

  defp segment_files(dir) do
    Path.wildcard(Path.join(dir, "#{@segment_prefix}*"))
    |> Enum.map(fn file ->
      idx =
        file
        |> Path.basename()
        |> String.replace_prefix(@segment_prefix, "")
        |> String.to_integer()

      {idx, file}
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
    :file.close(state.buf)

    next_index =
      if state.segment_index + 1 >= state.max_segments do
        delete_oldest_segment(state)
        0
      else
        state.segment_index + 1
      end

    file = segment_path(state.directory, next_index)

    case :file.open(file, [:append, :binary, :read, :write]) do
      {:ok, buf} -> {:ok, %{state | segment_index: next_index, file: file, buf: buf}}
      {:error, _} = err -> err
    end
  end

  defp delete_oldest_segment(state) do
    [{_, path} | _] =
      state.directory
      |> segment_files()
      |> Enum.sort()

    File.rm(path)
  end

  defp write_entry_to_buffer(entry, state) do
    bin = Entry.serialize(entry)
    size = byte_size(bin)

    :ok = :file.write(state.buf, <<size::little-32>>)
    :ok = :file.write(state.buf, bin)
    {:ok, state}
  end

  defp sync_impl(state) do
    :file.sync(state.buf)
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
