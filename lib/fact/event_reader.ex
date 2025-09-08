defmodule Fact.EventReader do
  use GenServer

  require Logger

  defmodule QueryClause do
    defstruct event_types: [], event_data: []
  end

  #defstruct [:events_dir, :append_log, :stream_dir]

  def start_link(opts) do
    {start_opts, reader_opts} = Keyword.split(opts, [:debug, :name, :timeout, :spawn_opt, :hibernate_after])

    state = %{
      events_dir: Keyword.fetch!(reader_opts, :events_dir),
      append_log: Keyword.fetch!(reader_opts, :append_log),
      stream_dir: Keyword.fetch!(reader_opts, :event_stream_index_dir),
      event_type_dir: Keyword.fetch!(reader_opts, :event_type_index_dir),
      event_data_dir: Keyword.fetch!(reader_opts, :event_data_index_dir)
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

  def query(clauses) when is_list(clauses) do
    GenServer.call(__MODULE__, {:query, clauses})
  end

  def query(%Fact.EventReader.QueryClause{} = clause) do
    GenServer.call(__MODULE__, {:query, [clause]})
  end

  def query(types \\ [], properties \\ []) do
    GenServer.call(__MODULE__, {:query, [%Fact.EventReader.QueryClause{event_types: types, event_data: properties}]})
  end


  # PRIVATE

  def init(state) do
    {:ok, state}
  end

  def handle_call({:read_all, from_pos}, _from, %{append_log: append_log, events_dir: events_dir} = state) do

    read_stream =
      append_log
      |> File.stream!()
      |> Stream.map(&String.trim/1)
      |> Stream.map(&Path.join(events_dir, "#{&1}.json"))
      |> Stream.with_index(1)
      |> Stream.drop_while(fn {_path, pos} -> pos <= from_pos end)
      |> Stream.map(fn {path, _pos} ->
        {:ok, encoded} = File.read(path)
        {:ok, event} = JSON.decode(encoded)
        event
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

  def handle_call({:query, clauses}, _from, state) when is_list(clauses) do

    events_matched =
      clauses
      |> Enum.reduce(MapSet.new(), fn clause, acc ->
        MapSet.union(acc, events_matching_clause(clause, state))
      end)

    read_stream =
      state.append_log
      |> File.stream!()
      |> Stream.map(&String.trim/1)
      |> Stream.filter(&MapSet.member?(events_matched, &1))
      |> Stream.map(&Path.join(state.events_dir, "#{&1}.json"))
      |> Stream.with_index(1)
      |> Stream.map(fn {path, pos} ->
          {:ok, encoded} = File.read(path)
          {:ok, event} = JSON.decode(encoded)
          Map.put(event, "query_position", pos)
        end)

    {:reply, read_stream, state}

  end

  defp events_matching_clause(%QueryClause{} = clause, state) do
    type_matches = events_matching_types(clause.event_types, state)
    data_matches = events_matching_data(clause.event_data, state)
    case {type_matches, data_matches} do
      {nil, nil} -> MapSet.new()
      {nil, data} -> data
      {types, nil} -> types
      {types, data} -> MapSet.intersection(types, data)
    end
  end

  defp events_matching_types([], _state), do: nil
  defp events_matching_types(event_types, state) do
    event_types
    |> Enum.map(&read_index(Path.join(state.event_type_dir, &1)))
    |> Enum.reduce(MapSet.new(), &MapSet.union/2)
  end

  defp events_matching_data(event_data, state) do
    Enum.reduce_while(event_data, nil, fn {key, value}, acc ->
      ids = read_index(Path.join([state.event_data_dir, to_string(key), sha1(value)]))
      case {acc, MapSet.size(ids) > 0} do
        {_, false} -> {:halt, MapSet.new()}
        {nil, true} -> {:cont, ids}
        {acc, true} -> {:cont, MapSet.intersection(acc, ids)}
      end
    end)
  end

  defp sha1(value) do
    binary = :erlang.term_to_binary(value)
    hash = :crypto.hash(:sha, binary)
    Base.encode16(hash, case: :lower)
  end

  defp read_index(path) do
    if File.exists?(path) do
      File.stream!(path)
      |> Stream.map(&String.trim/1)
      |> Enum.to_list()
      |> MapSet.new()
    else
      MapSet.new()
    end
  end

end
