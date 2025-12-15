defmodule Fact.QueryItem do
  @moduledoc """
  Provides functions for constructing query item structures and converting them into query functions.
    
  This module defines functions for building query items and combining them into lists.
  In Fact, a query item is a struct which defines criteria for matching events, on event types,
  event tags, and event data properties. A Fact database can be read using queries, and this
  module provides `to_function/1` for conveniently converting a single query item or list of
  query items into a query function.
    
      iex> Fact.QueryItem.tags("tag1")
      %Fact.QueryItem{data: [], tags: ["tag1"], types: []}
    
      iex> Fact.QueryItem.types("EventType1")
      %Fact.QueryItem{data: [], tags: [], types: ["EventType1"]}
    
      iex> Fact.QueryItem.data(name: "Jake")
      %Fact.QueryItem{data: [name: ["Jake"]]}

  Query items can be combined using the pipe operator.
    
      iex> Fact.QueryItem.tags("tag1") |> Fact.QueryItem.types("EventType1")
      %Fact.QueryItem{data: [], tags: ["tag1"], types: ["EventType1"]}

  This module ensures query items are normalized and prevent duplicates.

      iex> import Fact.QueryItem
      iex> tags(["tag2","tag1"]) |> tags(["tag1","tag3","tag2"])
      %Fact.QueryItem{data: [], tags: ["tag1", "tag2", "tag3"], types: []}
      iex> types("EventType1") |> types(["EventType2","EventType1"])
      %Fact.QueryItem{data: [], tags: [], types: ["EventType1", "EventType2"]}
      iex> data(name: "Jake", name: "Cob", name: "Jacob") |> data(name: "Jake", name: "Statefarm")
      %Fact.QueryItem{data: [name: ["Cob", "Jacob", "Jake", "Statefarm"]], tags: [], types: []}
    
  There are two special representations for query items, `all/1` and `none/1`. These are typically used
  as single query items when needed, but can be combined. Mathematically speaking, `all/1` acts as the 
  [identity](https://en.wikipedia.org/wiki/Identity_(mathematics)), and `none/0` acts as the 
  [zero object](https://en.wikipedia.org/wiki/Zero_object_(algebra)) in terms of combining query items.
    
      iex> import Fact.QueryItem
      iex> all()
      :all
      iex> none()
      :none
     
    
  Multiple query items can also be joined together to form a list which represents a compound query. At runtime,
  each query item is effectively combined with an OR, which often results in more Events being returned.

      iex> import Fact.QueryItem
      iex> join([
      ...>   types(["EventType1","EventType2"]),
      ...>   tags(["tag1", "tag2"]),
      ...>   types(["EventType2","EventType3"]) |> tags(["tag1","tag3"])
      ...> ])
      [
        %Fact.QueryItem{data: [], tags: ["tag1", "tag2"], types: []},
        %Fact.QueryItem{data: [], tags: [], types: ["EventType1", "EventType2"]},
        %Fact.QueryItem{
          data: [],
          tags: ["tag1", "tag3"],
          types: ["EventType2", "EventType3"]
        }
      ]
    
  > #### Info {: .info}
  >
  > The normalization process used when joining may change the order of the query items.
  """

  @type t ::
          %__MODULE__{data: keyword(), tags: list(String.t()), types: list(String.t())}
          | :all
          | :none

  defstruct data: [], tags: [], types: []

  @doc """
  Returns a query item that matches all events.

  When combined with another query item, it acts as the identity query item, and returns the specified query item.
    
      iex> import Fact.QueryItem
      iex> all()
      :all
      iex> tags("tag1") |> all()
      %Fact.QueryItem{data: [], tags: ["tag1"], types: []}
      iex> all() |> tags("tag1")
      %Fact.QueryItem{data: [], tags: ["tag1"], types: []}
    
  """
  @spec all(t()) :: t()
  def all(query_item \\ nil)

  def all(nil), do: :all

  def all(query_item) do
    if not is_query_item?(query_item) do
      raise ArgumentError, "invalid query item"
    end

    query_item
  end

  @doc """
  Returns a query item that matches no events.
    
  When combined with another query item, it acts as the zero object, and returns `:none`.
    
      iex> import Fact.QueryItem
      iex> none()
      :none
      iex> tags("tag1") |> none()
      :none
      iex> none() |> tags("tag1")
      :none
  """
  @spec none(t()) :: t()
  def none(query_item \\ %__MODULE__{}) do
    if not is_query_item?(query_item) do
      raise ArgumentError, "invalid query item"
    end

    :none
  end

  @doc """
  Returns a query item that matches event data properties.
    
  When duplicate keys are specified the individual values are evaluated as an OR when the query is executed.
      
      iex> Fact.QueryItem.data(name: "Jake", name: "Jacob")
      %Fact.QueryItem{data: [name: ["Jacob", "Jake"]], tags: [], types: []}

  In SQL terms, assuming event_data is a `jsonb` column, this would be equalivant to: 

      SELECT *
      FROM events
      WHERE event_data->>'name' IN ('Jacob', 'Jake')

  Distinct keys are effectively an AND when the query is executed.
    
      iex> Fact.QueryItem.data(name: "Jake", name: "Jacob", hobby: "Homebrewing")
      %Fact.QueryItem{
        data: [hobby: ["Homebrewing"], name: ["Jacob", "Jake"]], 
        tags: [], 
        types: []
      }
    
  In SQL terms, assuming event_data is a `jsonb` column, this would be equalivant to:  
    
      SELECT *
      FROM events
      WHERE event_data->>'hobby' = 'Homebrewing' 
        AND event_data->>'name' IN ('Jacob', 'Jake')
    
  Duplicate key value pairs are ignored.
    
      iex> import Fact.QueryItem
      iex> data(name: "Jake", name: "Jacob", name: "Jacob") |> data(name: "Jake")
      %Fact.QueryItem{data: [name: ["Jacob", "Jake"]], tags: [], types: []}
    
  Raises an ArgumentError when an invalid tag (not a string) is specified:
    
      iex> Fact.QueryItem.data({"key", "value"})
      ** (ArgumentError) invalid data keyword

      iex> Fact.QueryItem.data([{"key", "value"}])
      ** (ArgumentError) invalid data keyword
  """
  @spec data(t(), keyword()) :: t()
  def data(query_item \\ %__MODULE__{}, data)

  def data(query_item, data) when is_list(data) do
    if not Keyword.keyword?(data) do
      raise ArgumentError, "invalid data keyword"
    end

    case query_item do
      :all -> %__MODULE__{data: normalize_data(data)}
      :none -> :none
      %__MODULE__{} = q -> %__MODULE__{q | data: normalize_data(data ++ query_item.data)}
    end
  end

  def data(_, _), do: raise(ArgumentError, "invalid data keyword")

  @doc """
  Returns a query item that matches events with all specified event tags.
    
  Multiple tags are effectively an AND when a query is evaluated.
    
      iex> Fact.QueryItem.tags(["tag1", "tag2"])
      %Fact.QueryItem{data: [], tags: ["tag1", "tag2"], types: []}
    
  In SQL terms, this would be equivalent to:

       SELECT e.*
       FROM events e
       WHERE EXISTS (
         SELECT 1 FROM event_tags t 
         WHERE e.event_id = t.event_id AND t.tag = 'tag1')
       AND EXISTS (
         SELECT 1 FROM event_tags t 
         WHERE e.event_id = t.event_id AND t.tag = 'tag2')

  Duplicate tags are ignored.
    
      iex> import Fact.QueryItem
      iex> tags("tag1") |> tags(["tag1", "tag2", "tag2"])
      %Fact.QueryItem{data: [], tags: ["tag1", "tag2"], types: []}
    
  Raises an ArgumentError when an invalid tag (not a string) is specified:
    
      iex> Fact.QueryItem.tags(:not_a_tag)
      ** (ArgumentError) invalid event tag

      iex> Fact.QueryItem.tags([:not_a_tag])
      ** (ArgumentError) invalid event tag
  """
  @spec tags(t(), Fact.Types.event_tag() | nonempty_list(Fact.Types.event_tag())) :: t()
  def tags(query_item \\ %__MODULE__{}, tags)

  def tags(query_item, tag) when is_binary(tag) do
    case query_item do
      :all -> %__MODULE__{tags: [tag]}
      :none -> :none
      %__MODULE__{} = q -> %__MODULE__{q | tags: normalize_tags([tag | query_item.tags])}
    end
  end

  def tags(query_item, tags) when is_list(tags) do
    if not Enum.all?(tags, &is_binary/1) do
      raise ArgumentError, "invalid event tag"
    end

    case query_item do
      :all -> %__MODULE__{tags: normalize_tags(tags)}
      :none -> :none
      %__MODULE__{} = q -> %__MODULE__{q | tags: normalize_tags(tags ++ query_item.tags)}
    end
  end

  def tags(_, _), do: raise(ArgumentError, "invalid event tag")

  @doc """
  Returns a query item that matches events with any of the specified event types
    
  Multiple event types are effectively an OR when a query is evaluated.
    
      iex> Fact.QueryItem.types(["EventType1", "EventType2"])
      %Fact.QueryItem{data: [], tags: [], types: ["EventType1", "EventType2"]}
    
  In SQL terms, this would be equivalent to:

       SELECT *
       FROM events
       WHERE event_type IN ('EventType1', 'EventType2')

  Duplicate types are ignored.
    
      iex> import Fact.QueryItem
      iex> types(["EventType1", "EventType2"]) |> types(["EventType1", "EventType2"])
      %Fact.QueryItem{data: [], tags: [], types: ["EventType1", "EventType2"]}

  Raises an ArgumentError when an invalid type (not a string) is specified:
    
      iex> Fact.QueryItem.types(:not_a_type)
      ** (ArgumentError) invalid event type

      iex> Fact.QueryItem.types([:not_a_type])
      ** (ArgumentError) invalid event type
  """
  @spec types(t(), Fact.Types.event_type() | nonempty_list(Fact.Types.event_type())) :: t()
  def types(query_item \\ %__MODULE__{}, types)

  def types(query_item, type) when is_binary(type) do
    case query_item do
      :all -> %__MODULE__{types: [type]}
      :none -> :none
      %__MODULE__{} = q -> %__MODULE__{q | types: normalize_types([type | query_item.types])}
    end
  end

  def types(query_item, types) when is_list(types) do
    if not Enum.all?(types, &is_binary/1) do
      raise ArgumentError, "invalid event type"
    end

    case query_item do
      :all -> %__MODULE__{types: normalize_types(types)}
      :none -> :none
      %__MODULE__{} = q -> %__MODULE__{q | types: normalize_types(types ++ query_item.types)}
    end
  end

  def types(_, _), do: raise(ArgumentError, "invalid event type")

  @doc """
  This combines multiple query items into a list of query items to describe a compound query.
    
  Each query item is effectively combined with an OR.

      iex> import Fact.QueryItem
      iex> join([
      ...>   types(["EventType1","EventType2"]),
      ...>   tags(["tag1", "tag2"]),
      ...>   types(["EventType2","EventType3"]) |> tags(["tag1","tag3"])
      ...> ])
      [
        %Fact.QueryItem{data: [], tags: ["tag1", "tag2"], types: []},
        %Fact.QueryItem{data: [], tags: [], types: ["EventType1", "EventType2"]},
        %Fact.QueryItem{
          data: [],
          tags: ["tag1", "tag3"],
          types: ["EventType2", "EventType3"]
        }
      ]
    
  In SQL terms, this would be equivalent to:
    
      SELECT e.*
      FROM events e 
      WHERE 
        (EXISTS (
           SELECT 1 FROM event_tags t 
           WHERE e.event_id = t.event_id AND t.tag = 'tag1')
         AND EXISTS (
           SELECT 1 FROM event_tags t 
           WHERE e.event_id = t.event_id AND t.tag = 'tag2'))
      OR e.event_type IN ('EventType1', 'EventType2')
      OR (EXISTS (
            SELECT 1 FROM event_tags t 
            WHERE e.event_id = t.event_id AND t.tag = 'tag1')
          AND EXISTS (
            SELECT 1 FROM event_tags t 
            WHERE e.event_id = t.event_id AND t.tag = 'tag3')
          AND e.event_type IN ('EventType2', 'EventType3'))
    
  Duplicate query items are ignored.
    
      iex> import Fact.QueryItem
      iex> join([
      ...>   tags(["tag1","tag2"]),
      ...>   tags(["tag2","tag1"])
      ...> ])
      %Fact.QueryItem{data: [], tags: ["tag1", "tag2"], types: []}
    
  Joining `all/1` with any other query items will produce `:all`. In SQL, this is equivalent to `OR true`.
    
      iex> import Fact.QueryItem
      iex> join([
      ...>   tags(["tag1","tag2"]),
      ...>   all()
      ...> ])
      :all
    
  Joining `none/1` with any other query items will be ignored. In SQL, this is equivalent to `OR false`. 
    
      iex> import Fact.QueryItem
      iex> join([
      ...>   tags(["tag1","tag2"]),
      ...>   none()
      ...> ])
      %Fact.QueryItem{data: [], tags: ["tag1", "tag2"], types: []}
    
  Raises an `ArgumentError` when an invalid query item is supplied.
    
      iex> Fact.QueryItem.join([:invalid_query_item])
      ** (ArgumentError) invalid query item
  """
  @spec join(list(t())) :: list(t()) | t()
  def join([]), do: :all

  def join(query_items) when is_list(query_items) do
    if not Enum.all?(query_items, &is_query_item?/1) do
      raise ArgumentError, "invalid query item"
    end

    cond do
      Enum.all?(query_items, &match?(:none, &1)) ->
        :none

      Enum.any?(query_items, &match?(:all, &1)) ->
        :all

      true ->
        result =
          query_items
          |> Enum.reject(&match?(:none, &1))
          |> Enum.reduce(%{}, fn query, acc ->
            Map.put(acc, hash(query), query)
          end)
          |> Enum.sort_by(fn {hash, _query} -> hash end)
          |> Enum.map(fn {_hash, query} -> query end)

        case result do
          [single] -> single
          [_first | _rest] -> result
        end
    end
  end

  @doc """
  The `hash/1` function produces a sha-1 hash of a query item or list of query items.

  This function is used internally for normalization and caching.
    
      iex> import Fact.QueryItem
      iex> hash(all())
      "d6d864f6c0dacbd3d70b7d56f6811f799cefc0b1"
      iex> hash(none())
      "e91c644069975348a5eabdbf4340287bc05cc8a0"
      iex> join([
      ...>   tags("course:c1"),
      ...>   types("StudentSubscribedToCourse")
      ...> ]) |> hash()
      "b38d0dd5cebf77f1b4a1cf35ef0e5fed1790206c"

      iex> Fact.QueryItem.hash(:not_a_query_item)
      ** (ArgumentError) invalid query item
  """
  @spec hash(t() | list(t)) :: String.t()
  def hash(query_items) when is_list(query_items) do
    join(query_items)
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha, &1))
    |> Base.encode16(case: :lower)
  end

  def hash(query_item) do
    if not is_query_item?(query_item) do
      raise ArgumentError, "invalid query item"
    end

    query_item
    |> normalize()
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha, &1))
    |> Base.encode16(case: :lower)
  end

  @doc """
  Converts a query item or list of query items into a query function.

      iex> import Fact.QueryItem
      iex> fun1 = tags("tag1") |> to_function()
      iex> is_function(fun1, 1)
      :true
      iex> fun2 = join([
      ...>   types(["EventType1","EventType2"]),
      ...>   tags(["tag1", "tag2"]),
      ...>   types(["EventType2","EventType3"]) |> tags(["tag1","tag3"])
      ...> ]) |> to_function()
      iex> is_function(fun2, 1)
      :true
      
  """
  @spec to_function(t() | nonempty_list(t())) :: Fact.Query.t()
  def to_function([%__MODULE__{} | _] = query_items) when is_list(query_items) do
    Fact.Query.combine!(:or, Enum.map(query_items, &to_function/1))
  end

  def to_function(:all), do: Fact.Query.from_all()
  def to_function(:none), do: Fact.Query.from_none()

  def to_function(%__MODULE__{} = query_item) do
    normalized = normalize(query_item)
    {:ok, fun} = Fact.Query.from(normalized.types, normalized.tags, explode(normalized.data))
    fun
  end

  defp explode(values) do
    Enum.flat_map(values, fn {k, v} -> Enum.map(v, &{k, &1}) end)
  end

  defp is_query_item?(value) do
    match?(:all, value) or match?(:none, value) or match?(%__MODULE__{}, value)
  end

  defp normalize(:all), do: :all
  defp normalize(:none), do: :none

  defp normalize(%__MODULE__{} = item) do
    %__MODULE__{
      data: normalize_data(item.data),
      tags: normalize_tags(item.tags),
      types: normalize_types(item.types)
    }
  end

  defp normalize_data(data) when is_list(data) do
    data
    |> Enum.reduce(%{}, fn {k, v}, acc ->
      values =
        case v do
          l when is_list(l) -> l
          s -> [s]
        end

      Map.update(acc, k, values, fn existing -> existing ++ values end)
    end)
    |> Enum.map(fn {k, v} ->
      {k, v |> Enum.uniq() |> Enum.sort()}
    end)
    |> Enum.sort_by(fn {k, _} -> k end)
  end

  defp normalize_tags(tags) when is_list(tags) do
    tags |> Enum.uniq() |> Enum.sort()
  end

  defp normalize_types(types) when is_list(types) do
    types |> Enum.uniq() |> Enum.sort()
  end
end
