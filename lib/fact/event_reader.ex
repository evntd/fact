defmodule Fact.EventReader do
  use Fact.EventKeys
  alias Fact.Paths
  require Logger

  defmodule QueryClause do
    defstruct event_types: [], event_data: []
  end

  def read_all(opts \\ []) do
    from_pos = Keyword.get(opts, :from_position, 0)

    events_path = Paths.events
    read_stream =
      Paths.append_log
      |> File.stream!()
      |> Stream.map(&String.trim/1)
      |> Stream.map(&Path.join(events_path, "#{&1}.json"))
      |> Stream.with_index(1)
      |> Stream.drop_while(fn {_path, pos} -> pos <= from_pos end)
      |> Stream.map(fn {path, _pos} ->
        {:ok, encoded} = File.read(path)
        {:ok, event} = JSON.decode(encoded)
        event
      end)

    read_stream
  end

  def read_stream(stream, opts \\ []) do
    from_pos = Keyword.get(opts, :from_position, 0)

    events_path = Paths.events
    event_stream_file = Path.join(Paths.index(:event_stream), stream)
    if File.exists?(event_stream_file) do
      read_stream =
        event_stream_file
        |> File.stream!()
        |> Stream.map(&String.trim/1)
        |> Stream.map(&Path.join(events_path, "#{&1}.json"))
        |> Stream.with_index(1)
        |> Stream.drop_while(fn {_path, pos} -> pos <= from_pos end)
        |> Stream.map(fn {path, pos} ->
          {:ok, encoded} = File.read(path)
          {:ok, event} = JSON.decode(encoded)
          Map.put(event, @event_stream_position, pos)
        end)

      read_stream
    else
      {:error, :stream_not_found}
    end    
  end

  def query(clauses) when is_list(clauses) do
    events_matched =
      clauses
      |> Enum.reduce(MapSet.new(), fn clause, acc ->
        MapSet.union(acc, events_matching_clause(clause))
      end)
      
    events_dir = Paths.events
    
    Paths.append_log
    |> File.stream!()
    |> Stream.map(&String.trim/1)
    |> Stream.filter(&MapSet.member?(events_matched, &1))
    |> Stream.map(&Path.join(events_dir, "#{&1}.json"))
    |> Stream.with_index(1)
    |> Stream.map(fn {path, pos} ->
      {:ok, encoded} = File.read(path)
      {:ok, event} = JSON.decode(encoded)
      Map.put(event, @query_position, pos)
    end)
  end

  def query(%Fact.EventReader.QueryClause{} = clause), do: query([clause])
  def query(types \\ [], properties \\ []), do: query([%Fact.EventReader.QueryClause{event_types: types, event_data: properties}])

  # PRIVATE

  defp events_matching_clause(%QueryClause{} = clause) do
    type_matches = events_matching_types(clause.event_types)
    data_matches = events_matching_data(clause.event_data)
    case {type_matches, data_matches} do
      {nil, nil} -> MapSet.new()
      {nil, data} -> data
      {types, nil} -> types
      {types, data} -> MapSet.intersection(types, data)
    end
  end

  defp events_matching_types([]), do: nil
  defp events_matching_types(event_types) do
    event_type_dir = Paths.index(:event_type)
    event_types
    |> Enum.map(&read_index(Path.join(event_type_dir, &1)))
    |> Enum.reduce(MapSet.new(), &MapSet.union/2)
  end

  defp events_matching_data(event_data) do
    event_data_dir = Paths.index(:event_data)
    Enum.reduce_while(event_data, nil, fn {key, value}, acc ->
      {:ok, _pid} = Fact.EventDataIndexerManager.ensure_indexer(key)
      ids = read_index(Path.join([event_data_dir, to_string(key), sha1(value)]))
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
