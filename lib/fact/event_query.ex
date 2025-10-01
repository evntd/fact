defmodule Fact.EventQuery do
  @moduledoc """
  Provides an interface for querying events based on event types and event data properties.
    
  This module allows you to define a query using `Fact.EventQuery` structs, specifying:
    
  - `:types` - a list of strings or atoms representing the types of events to match.
  - `:tags` - a list of strings representing the tags of events to match
  - `:data` - a keyword list used to filter events based on their properties and values.
    
  The primary function, `execute/1`, produces a **stream of event ids** that match the provided query in the order they
  appear in the `Fact.EventLedger`. Queries are limited to **equality operations only**. You can filter events by type
  and by exact matches on event data properties, but no other operators (e.g. ranges, greater/less than, pattern 
  matching) are supported. This is an intentional design decision, this is not for general purpose data queries, it is
  intended to be used for defining consistency boundaries.

  ## Query Execution
    
  - Combines multiple queries using **OR** semantics.
  - Combines multiple values for the same key in a single query using **OR** semantics.
  - Combines different keys in a single query using **AND** semantics.
    
  The module interacts with `Fact.EventIndexerManager` to access `Fact.EventTypeIndexer` and `Fact.EventDataIndexer`. 
  Event data properties included in queries will enable just-in-time indexing via a keyed `Fact.EventDataIndexer`. This
  dynamic indexing comes at the cost of a performance hit as the query must wait for the index to be built. To  
  counteract this, all indexers support incremental indexing by keep track of the last processed event.

  ## Example
    
      query = [ 
          %Fact.EventQuery{
            event_types: ["hops_harvested"],
            event_data: [
              cultivar: "Cascade",
              cultivar: "Centennial",
              date: "2025-09-01",
              grower: "Goschie Farms"
            ]
          },
          %Fact.EventQuery{
            event_types: ["hops_dried"],
            event_data: [
              finish_date: "2025-09-03"
            ]
          }
      ]
    
      Fact.EventQuery.execute(query)
      |> Enum.each(&IO.inspect/1)
    
  Now this query might not be all the useful for your use case, but it will return an ordered set of event ids, for all 
  the `hops_harvested` events for `cascade` and `centennial` on September 1st, 2025, by Goschie Farms AND all 
  `hops_dried` events where they finished on September 3rd, 2025.
    
  ## Integration
    
  This module is designed to work seamlessly with `Fact.EventReader`. You can pass a `%Fact.EventQuery{}` or a list of
  them directly to `Fact.EventReader.read/2` to get a stream of fully materialized events instead of event ids.  
  """

  defstruct types: [], tags: [], data: []

  @type t :: %__MODULE__{
          types: [Fact.Types.event_type()],
          tags: Fact.Types.event_tags(),
          data: keyword()
        }

  @doc """
  Executes a single or multiple event queries and returns a stream of matching event ids in the order they appear in the 
  event ledger.
    
  `clauses` - a list of `%Fact.EventQuery{}` structs. Results from multiple clauses are combined using set union 
  (`OR` semantics).
    
  Each clause is evaluated against a configured event indexer.  
  - `event_types` are resolved through the `Fact.EventTypeIndexer`
  - `event_data` entries are resolved through one or more `Fact.EventDataIndexer`'s, unioning values for the same key 
    (`OR`) and intersecting values for different keys (`AND`).

  The union of all matching event ids is then filtered against the event ledger, producing a lazily evaluated `Stream` 
  of event ids in append order.
  """
  @spec execute(atom, t() | [t()]) :: Stream.t(String.t())
  def execute(instance, clauses, opts \\ [])
  def execute(instance, %__MODULE__{} = clause, opts), do: execute(instance, [clause], opts)

  def execute(instance, clauses, opts) when is_list(clauses) do
    if Enum.all?(clauses, &match?(%__MODULE__{}, &1)) do
      matched_event_ids =
        Enum.reduce(clauses, MapSet.new(), &MapSet.union(&2, events_matching(instance, &1)))

      direction = Keyword.get(opts, :direction, :forward)

      Fact.Storage.read_index(instance, :ledger, direction)
      |> Stream.filter(&MapSet.member?(matched_event_ids, &1))
    else
      raise ArgumentError, "All elements must be %#{__MODULE__}{}"
    end
  end

  defp events_matching(instance, %{
         types: types,
         tags: tags,
         data: data
       }) do
    type_matches = events_matching_types(instance, types)
    tag_matches = events_matching_tags(instance, tags)
    data_matches = events_matching_data(instance, data)

    case {types, tags, data} do
      {[], [], []} ->
        MapSet.new()

      {_, [], []} ->
        type_matches

      {[], _, []} ->
        tag_matches

      {[], [], _} ->
        data_matches

      {_, _, []} ->
        type_matches
        |> MapSet.intersection(tag_matches)

      {_, [], _} ->
        type_matches
        |> MapSet.intersection(data_matches)

      {[], _, _} ->
        tag_matches
        |> MapSet.intersection(data_matches)

      {_, _, _} ->
        type_matches
        |> MapSet.intersection(tag_matches)
        |> MapSet.intersection(data_matches)
    end
  end

  defp events_matching_types(_instance, []), do: MapSet.new()

  defp events_matching_types(instance, types) do
    types
    |> Stream.flat_map(&Fact.EventIndexerManager.stream!(instance, Fact.EventTypeIndexer, &1))
    |> Enum.into(MapSet.new())
  end

  defp events_matching_tags(_instance, []), do: MapSet.new()

  defp events_matching_tags(instance, tags) do
    Enum.reduce(tags, :first, fn tag, acc ->
      matches_tag =
        Fact.EventIndexerManager.stream!(instance, Fact.EventTagsIndexer, tag)
        |> Enum.into(MapSet.new())

      case acc do
        :first -> matches_tag
        _ -> MapSet.intersection(acc, matches_tag)
      end
    end)
  end

  defp events_matching_data(instance, data) do
    data
    |> Enum.group_by(fn {k, _} -> k end, fn {_, v} -> v end)
    |> Enum.reduce_while(:first, fn {key, values}, acc ->
      indexer = {Fact.EventDataIndexer, to_string(key)}
      {:ok, _pid} = Fact.EventIndexerManager.ensure_indexer(instance, indexer)

      ids =
        values
        |> Enum.flat_map(fn value ->
          case Fact.EventIndexerManager.stream!(instance, indexer, value) do
            {:error, _} -> []
            streamable -> Enum.to_list(streamable)
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
