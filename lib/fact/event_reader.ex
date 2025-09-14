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

  def read_stream(event_stream, opts \\ []) do
    from_pos = Keyword.get(opts, :from_position, 0)
    events_path = Paths.events
    
    Fact.EventIndexerManager.stream(Fact.EventStreamIndexer, event_stream)
    |> Stream.map(&Path.join(events_path, "#{&1}.json"))
    |> Stream.with_index(1)
    |> Stream.drop_while(fn {_path, pos} -> pos <= from_pos end)
    |> Stream.map(fn {path, pos} ->
      {:ok, encoded} = File.read(path)
      {:ok, event} = JSON.decode(encoded)
      Map.put(event, @event_stream_position, pos)
    end)
    
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
      Map.put(event, @event_query_position, pos)
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
    event_types
    |> Stream.flat_map(&Fact.EventIndexerManager.stream(Fact.EventTypeIndexer, &1))
    |> Enum.into(MapSet.new())
  end

  defp events_matching_data(event_data) do
    event_data
    |> Enum.group_by(fn {k,_} -> k end, fn {_,v} -> v end)
    |> Enum.reduce_while(:first, fn {key, values}, acc ->
      indexer = {Fact.EventDataIndexer, to_string(key)}
      {:ok, _pid} = Fact.EventIndexerManager.ensure_indexer(indexer)
      
      ids =
        values 
        |> Enum.flat_map(fn value ->
          case Fact.EventIndexerManager.stream(indexer, value) do
            streamable -> Enum.to_list(streamable)
            {:error, _} -> []
          end
        end)
        |> MapSet.new()
      
      cond do
        MapSet.size(ids) == 0 ->
          {:halt, MapSet.new()}
        acc == :first ->
          {:cont, ids}
        true ->
          {:cont, MapSet.intersection(acc, ids)}
      end
    end)
    |> case do 
      :first -> MapSet.new()
      result -> result
     end
  end
end
