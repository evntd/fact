defmodule Fact.QueryItem do
  @moduledoc """
  Provides utilities for defining queries as a data structure.
  """

  @type t ::
          %__MODULE__{data: keyword(), tags: list(String.t()), types: list(String.t())}
          | :all
          | :none

  defstruct data: [], tags: [], types: []

  @spec all() :: t()
  def all(), do: :all
  
  @spec none() :: t()
  def none(), do: :none

  @spec data(t(), keyword()) :: t()
  def data(query_item \\ %__MODULE__{}, data) when is_list(data) do
    if not Enum.all?(data, &Keyword.keyword?/1) do
      raise ArgumentError, "all data values must be keywords"
    end

    case query_item do
      :all -> %__MODULE__{data: normalize_data(data)}
      :none -> :none
      %__MODULE__{} -> %__MODULE__{query_item | data: normalize_data(data ++ query_item.data)}
    end
  end
  
  @spec tags(t(), Fact.Types.event_tag() | nonempty_list(Fact.Types.event_tag())) :: t()
  def tags(query_item \\ %__MODULE__{}, tags)

  def tags(query_item, tag) when is_binary(tag) do
    case query_item do
      :all -> %__MODULE__{tags: [tag]}
      :none -> :none
      %__MODULE__{} -> %__MODULE__{query_item | tags: normalize_tags([tag | query_item.tags])}
    end
  end

  def tags(query_item, tags) when is_list(tags) do
    if not Enum.all?(tags, &is_binary/1) do
      raise ArgumentError, "all tags must be strings"
    end

    case query_item do
      :all -> %__MODULE__{tags: normalize_tags(tags)}
      :none -> :none
      %__MODULE__{} -> %__MODULE__{query_item | tags: normalize_tags(tags ++ query_item.tags)}
    end
  end

  @spec types(t(), Fact.Types.event_type() | nonempty_list(Fact.Types.event_type())) :: t()
  def types(query_item \\ %__MODULE__{}, types)
  
  def types(query_item, type) when is_binary(type) do
    case query_item do
      :all -> %__MODULE__{types: [type]}
      :none -> :none
      %__MODULE__{} -> %__MODULE__{query_item | types: normalize_types([type | query_item.types])}
    end
  end

  def types(query_item, types) when is_list(types) do
    if not Enum.all?(types, &is_binary/1) do
      raise ArgumentError, "all types must be strings"
    end

    case query_item do
      :all -> %__MODULE__{types: normalize_types(types)}
      :none -> :none
      %__MODULE__{} -> %__MODULE__{query_item | types: normalize_types(types ++ query_item.types)}
    end
  end

  @spec join(list(t())) :: list(t())
  def join([]), do: :all
  def join(query_items) when is_list(query_items) do
    if not Enum.all?(query_items, &is_query_item?/1) do
      raise ArgumentError, "contains values that are not valid query items"
    end

    cond do
      Enum.all?(query_items, &match?(:none, &1)) ->
        :none

      Enum.any?(query_items, &match?(:all, &1)) ->
        :all

      true ->
        query_items
        # filter out :none
        |> Enum.filter(&match?(%__MODULE__{}, &1))
        |> Enum.reduce(%{}, fn query, acc ->
          Map.put(acc, hash(query), query)
        end)
        |> Enum.sort_by(fn {hash, _query} -> hash end)
        |> Enum.map(fn {_hash, query} -> query end)
    end
  end

  @spec hash(t() | list(t)) :: String.t()
  def hash(query_items) when is_list(query_items) do
    join(query_items)
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha, &1))
    |> Base.encode16(case: :lower)
  end

  def hash(query_item) do
    if not is_query_item?(query_item) do
      raise ArgumentError, "must supply a valid query item"
    end

    query_item
    |> normalize()
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha, &1))
    |> Base.encode16(case: :lower)
  end

  @spec to_function(t() | nonempty_list(t())) :: Fact.Query.t()
  def to_function([%__MODULE__{} | _] = query_items) when is_list(query_items) do
    Fact.Query.combine!(:or, Enum.map(query_items, &to_function/1))
  end
  
  def to_function(:all), do: Fact.Query.from_all()
  def to_function(:none), do: Fact.Query.from_none()
  def to_function(%__MODULE__{} = query_item) do
    normalized = normalize(query_item)
    {:ok, fun} = Fact.Query.from(normalized.types, normalized.tags, normalized.data)
    fun
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
