defmodule Fact.EventReader do
  use GenServer
  require Logger

  defstruct [:events_dir, :append_log, :stream_dir]

  def start_link(opts) do
    {start_opts, reader_opts} = Keyword.split(opts, [:debug, :name, :timeout, :spawn_opt, :hibernate_after])

    state = %__MODULE__{
      events_dir: Keyword.fetch!(reader_opts, :events_dir),
      append_log: Keyword.fetch!(reader_opts, :append_log),
      stream_dir: Keyword.fetch!(reader_opts, :event_stream_index_dir)
    }

    start_opts = Keyword.put_new(start_opts, :name, __MODULE__)

    GenServer.start_link(__MODULE__, state, start_opts)

  end

  def read_all(opts \\ []) do
    from_pos = Keyword.get(opts, :from_position, 0)
    GenServer.call(__MODULE__, {:read_all, from_pos})
  end

  def read_stream(stream, opts \\ []) do
    from_pos = Keyword.get(opts, :from_position, 0)
    GenServer.call(__MODULE__, {:read_stream, stream, from_pos})
  end

  def init(state) do
    {:ok, state}
  end

  def handle_call({:read_all, from_pos}, _from, %__MODULE__{append_log: append_log, events_dir: events_dir} = state) do

    read_stream =
      append_log
      |> File.stream!()
      |> Stream.map(&String.trim/1)
      |> Stream.map(&Path.join(events_dir, "#{&1}.json"))
      |> Stream.with_index(1)
      |> Stream.drop_while(fn {_path, pos} -> pos <= from_pos end)
      |> Stream.map(fn {path, pos} ->
        {:ok, encoded} = File.read(path)
        {:ok, event} = JSON.decode(encoded)
        Map.put(event, "pos", pos)
      end)

    {:reply, read_stream, state}

  end

  def handle_call({:read_stream, stream, from_pos}, _from, %{stream_dir: stream_dir, events_dir: events_dir} = state) do

    eventstream_file = Path.join(stream_dir, stream)
    if File.exists?(eventstream_file) do

      read_stream =
        eventstream_file
        |> File.stream!()
        |> Stream.map(&String.trim/1)
        |> Stream.map(&Path.join(events_dir, "#{&1}.json"))
        |> Stream.with_index(1)
        |> Stream.drop_while(fn {_path, pos} -> pos <= from_pos end)
        |> Stream.map(fn {path, pos} ->
          {:ok, encoded} = File.read(path)
          {:ok, event} = JSON.decode(encoded)
          Map.put(event, "stream_position", pos)
        end)

      {:reply, read_stream, state}
    else
      {:reply, {:error, :stream_not_found}, state}
    end

  end
end
