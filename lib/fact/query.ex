defmodule Fact.Query do
  @moduledoc """
  Provide utilities for constructing event queries for defining consistency boundaries and projection sources.
    
  A **query** in the Fact system is a higher-order function that takes a database context and returns a predicate
  function. This predicate is used by `Fact.read/2` and related functions to determine whether each event in the
  database should be included in the result set.
    
  ## Query Construction
    
  This module offers several ways to build queries:
    
  * `from_types/1` - match events with an `event_type` contained in a supplied list.
  * `from_tags/1` - match events with `event_tags` containing *all* given tags.
  * `from_data/1` - match events with `event_data` containing specific key-value pairs.
  * `from_all/0` - match all events.
  * `from_none/0` - match no events.
  * `from/3` - a convenience wrapper that combines types, tags, and data into a single compound query.
  * `combine/2` - combines a list of queries using `:and` or `:or` boolean operations to produce a compound query.
  """

  @typedoc """
  A query is function which takes a database context and returns an event_id predicate function. 
  """
  @type t :: (Fact.Context.t() -> (Fact.Types.event_id() -> boolean()))

  @doc """
  This combines multiple queries using logical boolean operations returning a new query as a tuple.
  """
  @spec combine(:and | :or, [t(), ...]) :: {:ok, t()} | {:error, term()}
  def combine(op, queries) when is_list(queries) do
    if queries |> Enum.all?(&is_function/1) do
      case {op, queries} do
        {_op, []} ->
          {:error, :empty_query_list}

        {_op, [query]} ->
          {:ok, query}

        {:and, queries} ->
          fun =
            fn context ->
              match_funs = Enum.map(queries, fn q -> q.(context) end)

              fn event_id ->
                Enum.all?(match_funs, fn m -> m.(event_id) end)
              end
            end

          {:ok, fun}

        {:or, queries} ->
          fun =
            fn context ->
              match_funs = Enum.map(queries, fn q -> q.(context) end)

              fn event_id ->
                Enum.any?(match_funs, fn m -> m.(event_id) end)
              end
            end

          {:ok, fun}

        {_op, _queries} ->
          {:error, :invalid_op}
      end
    else
      {:error, :non_function_query}
    end
  end

  @doc """
  This combines multiple queries using logical boolean operations returning a new query.
  """
  @spec combine!(:and | :or, [t(), ...]) :: t()
  def combine!(op, queries) do
    case combine(op, queries) do
      {:ok, query} ->
        query

      {:error, :empty_query_list} ->
        raise ArgumentError, "must supply at least one query function"

      {:error, :invalid_op} ->
        raise ArgumentError, "invalid operation #{op}, use :and or :or"

      {:error, :non_function_query} ->
        raise ArgumentError,
              "each query must be a function (:Fact.Context.t() -> (Fact.Types.event_id() -> boolean()))"
    end
  end

  @doc """
  This is a helper function for creating compound queries.
    
  This provides a shortcut for writing:
    
      Fact.Query.combine(:and, [
        Fact.Query.from_types("StudentSubscribedToCourse"), 
        Fact.Query.from_tags("course:c1"),
        Fact.Query.from_data(student_id: "s1")
      ])
    
  Which could be shortened to:
    
      Fact.Query.from("StudentSubscribedToCourse", "course:c1", student_id: "s1")
  """
  @spec from(
          Fact.Types.event_type() | [Fact.Types.event_type(), ...],
          Fact.Types.event_tag() | [Fact.Types.event_tag(), ...],
          keyword()
        ) :: {:ok, t()} | {:error, term()}
  def from(types \\ [], tags \\ [], data \\ [])
  def from(nil, nil, nil), do: {:error, :no_criteria}
  def from([], [], []), do: {:error, :no_criteria}

  def from(types, tags, data) when (is_nil(tags) or tags == []) and (is_nil(data) or data == []),
    do: from_types(types)

  def from(types, tags, data)
      when (is_nil(types) or types == []) and (is_nil(data) or data == []),
      do: from_tags(tags)

  def from(types, tags, data)
      when (is_nil(types) or types == []) and (is_nil(tags) or tags == []),
      do: from_data(data)

  def from(types, tags, data) when is_nil(data) or data == [] do
    with {:ok, q1} <- from_types(types), {:ok, q2} <- from_tags(tags), do: combine(:and, [q1, q2])
  end

  def from(types, tags, data) when is_nil(tags) or tags == [] do
    with {:ok, q1} <- from_types(types), {:ok, q2} <- from_data(data), do: combine(:and, [q1, q2])
  end

  def from(types, tags, data) when is_nil(types) or types == [] do
    with {:ok, q1} <- from_tags(tags), {:ok, q2} <- from_data(data), do: combine(:and, [q1, q2])
  end

  def from(types, tags, data) do
    with {:ok, q1} <- from_types(types),
         {:ok, q2} <- from_tags(tags),
         {:ok, q3} <- from_data(data),
         do: combine(:and, [q1, q2, q3])
  end

  @doc """
  Create a query which matches all events.
  """
  @spec from_all() :: t()
  def from_all() do
    fn _context ->
      fn _event_id ->
        true
      end
    end
  end

  @doc """
  Creates a query which matches events with all the supplied key value pairs and returns it in a tuple.
  When duplicate keys are provided, the query will match events with any supplied values.
    
  ## Examples
    
  Get all events with a capacity of 10.
    
      iex> {:ok, query} = Fact.Query.from_data(capacity: 10)
      iex> Fact.read(:mydb, query) |> Enum.to_list()
      [
        %{                                                                                                                                                                                                                                                                                                                
          "event_data" => %{"capacity" => 10, "course_id" => "c1"},                                                                                                                                                                                                                                                       
          "event_id" => "a7f82f20b49549748a412797ef6b3c3d",                                                                                                                                                                                                                                                               
          "event_metadata" => %{},                                                                                                                                                                                                                                                                                        
          "event_tags" => ["course:c1"],                                                                                                                                                                                                                                                                                  
          "event_type" => "CourseDefined",                                                                                                                                                                                                                                                                                
          "store_position" => 1,                                                                                                                                                                                                                                                                                          
          "store_timestamp" => 1765222610917506                                                                                                                                                                                                                                                                           
        },                                                                                                                                                                                                                                                                                                                
        %{                                                                                                                                                                                                                                                                                                                
          "event_data" => %{"capacity" => 10, "course_id" => "c4"},                                                                                                                                                                                                                                                       
          "event_id" => "b7a5c4b71f4649e78a2a3347a23331df",                                                                                                                                                                                                                                                               
          "event_metadata" => %{},                                                                                                                                                                                                                                                                                        
          "event_tags" => ["course:c4"],                                                                                                                                                                                                                                                                                  
          "event_type" => "CourseDefined",                                                                                                                                                                                                                                                                                
          "store_position" => 4,                                                                                                                                                                                                                                                                                          
          "store_timestamp" => 1765224048824117                                                                                                                                                                                                                                                                           
        }                                                                                                                                                                                                                                                                                                                 
      ]
    
  Get all events with a matching course_id and capacity of 10.
    
      iex> {:ok, query} = Fact.Query.from_data(capacity: 10, course_id: "c1")
      iex> Fact.read(:mydb, query) |> Enum.to_list()
      [
        %{                                                                                                                                                                                                                                                                                                                
          "event_data" => %{"capacity" => 10, "course_id" => "c1"},                                                                                                                                                                                                                                                       
          "event_id" => "a7f82f20b49549748a412797ef6b3c3d",                                                                                                                                                                                                                                                               
          "event_metadata" => %{},                                                                                                                                                                                                                                                                                        
          "event_tags" => ["course:c1"],                                                                                                                                                                                                                                                                                  
          "event_type" => "CourseDefined",                                                                                                                                                                                                                                                                                
          "store_position" => 1,                                                                                                                                                                                                                                                                                          
          "store_timestamp" => 1765222610917506                                                                                                                                                                                                                                                                           
        }                                                                                                                                                                                                                                                                                                                
      ]
    
  Get all events with a matching course_id and a capacity of 10 or 15.
    
      iex> {:ok, query} = Fact.Query.from_data(course_id: "c1", capacity: 10, capacity: 15)
      iex> Fact.read(:mydb, query) |> Enum.to_list()
      [
        %{                                                                                                                                                                                                                                                                                                                
          "event_data" => %{"capacity" => 10, "course_id" => "c1"},                                                                                                                                                                                                                                                       
          "event_id" => "a7f82f20b49549748a412797ef6b3c3d",                                                                                                                                                                                                                                                               
          "event_metadata" => %{},                                                                                                                                                                                                                                                                                        
          "event_tags" => ["course:c1"],                                                                                                                                                                                                                                                                                  
          "event_type" => "CourseDefined",                                                                                                                                                                                                                                                                                
          "store_position" => 1,                                                                                                                                                                                                                                                                                          
          "store_timestamp" => 1765222610917506                                                                                                                                                                                                                                                                           
        },                                                                                                                                                                                                                                                                                                                
        %{                                                                                                                                                                                                                                                                                                                
          "event_data" => %{"capacity" => 15, "course_id" => "c1"},                                                                                                                                                                                                                                                       
          "event_id" => "2f575ea536a84b348b5738fd8785dbc7",                                                                                                                                                                                                                                                               
          "event_metadata" => %{},                                                                                                                                                                                                                                                                                        
          "event_tags" => ["course:c1"],                                                                                                                                                                                                                                                                                  
          "event_type" => "CourseCapacityChanged",                                                                                                                                                                                                                                                                        
          "store_position" => 12,                                                                                                                                                                                                                                                                                         
          "store_timestamp" => 1765301503964237                                                                                                                                                                                                                                                                           
        }                                                                                                                                                                                                                                                                                                                 
      ]

  """
  @spec from_data(keyword()) :: {:ok, t()} | {:error, term()}
  def from_data([]), do: {:error, :empty_data_list}

  def from_data(data) when is_list(data) do
    fun =
      fn context ->
        matching_events =
          data
          |> Enum.group_by(fn {k, _} -> k end, fn {_, v} -> v end)
          |> Enum.reduce_while(:first, fn {key, values}, acc ->
            {:ok, indexer_id} =
              Fact.Database.ensure_indexer(context, Fact.EventDataIndexer, key: to_string(key))

            ids =
              values
              |> Enum.flat_map(fn value ->
                case Fact.IndexFile.read(context, indexer_id, value) do
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

        fn event_id ->
          MapSet.member?(matching_events, event_id)
        end
      end

    {:ok, fun}
  end

  def from_data(_data), do: {:error, :invalid_data_criteria}

  @doc """
  Creates a query which matches events with all the supplied key value pairs.
  When duplicate keys are provided, the query will match events with any supplied values.

  Raises `ArgumentError` when no keywords are supplied.
  """
  @spec from_data!(keyword()) :: t()
  def from_data!(data) do
    case from_data(data) do
      {:ok, query} ->
        query

      {:error, :empty_data_list} ->
        raise ArgumentError, "must supply at least one keyword"

      {:error, :invalid_data_criteria} ->
        raise ArgumentError, "each data element must be a keyword or {String.t(), String.t()}"
    end
  end

  @doc """
  Create a query which matches no events.
    
  ## Examples
    
      iex> query = Fact.Query.from_none()
      iex> Fact.read(:mydb, query) |> Enum.to_list()
      []
  """
  @spec from_none() :: t()
  def from_none() do
    fn _context ->
      fn _event_id ->
        false
      end
    end
  end

  @doc """
  Creates a query which matches events tagged with all the supplied tags and returns it in a tuple.
    
  ## Examples
    
  Get all events tagged with `student:s1`.
    
      iex> {:ok, query} = Fact.Query.from_tags(["student:s1"])
      iex> Fact.read(:mydb, query) |> Enum.to_list()
      [
        %{                                                                                                                                                                                                                                                                                                                
          "event_data" => %{"student_id" => "s1"},                                                                                                                                                                                                                                                                        
          "event_id" => "ead3e5c6a78b493fade1b9fbad68ee35",                                                                                                                                                                                                                                                               
          "event_metadata" => %{},                                                                                                                                                                                                                                                                                        
          "event_tags" => ["student:s1"],                                                                                                                                                                                                                                                                                 
          "event_type" => "StudentRegistered",                                                                                                                                                                                                                                                                            
          "store_position" => 6,                                                                                                                                                                                                                                                                                         
          "store_timestamp" => 1765224325494777                                                                                                                                                                                                                                                                           
        },
        %{                                                                                                                                                                                                                                                                                                                
          "event_data" => %{"course_id" => "c1", "student_id" => "s1"},                                                                                                                                                                                                                                                   
          "event_id" => "90441ac451c74a82ba0e643b510ad429",                                                                                                                                                                                                                                                               
          "event_metadata" => %{},                                                                                                                                                                                                                                                                                        
          "event_tags" => ["course:c1", "student:s1"],                                                                                                                                                                                                                                                                    
          "event_type" => "StudentSubscribedToCourse",                                                                                                                                                                                                                                                                    
          "store_position" => 10,                                                                                                                                                                                                                                                                                          
          "store_timestamp" => 1765242156981475                                                                                                                                                                                                                                                                           
        },                                                                                                                                                                                                                                                                                                                
        %{                                                                                                                                                                                                                                                                                                                
          "event_data" => %{"course_id" => "c3", "student_id" => "s1"},                                                                                                                                                                                                                                                   
          "event_id" => "7ddcbe4fc32f40ac943661a69066f4ef",                                                                                                                                                                                                                                                               
          "event_metadata" => %{},                                                                                                                                                                                                                                                                                        
          "event_tags" => ["student:s1", "course:c3"],                                                                                                                                                                                                                                                                    
          "event_type" => "StudentSubscribedToCourse",                                                                                                                                                                                                                                                                    
          "store_position" => 11,                                                                                                                                                                                                                                                                                         
          "store_timestamp" => 1765242258559384                                                                                                                                                                                                                                                                           
        }                                                                                                                                                                                                                                                                                                                 
      ]
    
  Get all events tagged with both `course:c1` and `student:s1`
      
      iex> {:ok, query} = Fact.Query.from_tags(["course:c1","student:s1"])
      iex> Fact.read(:mydb, query) |> Enum.to_list()
      [
        %{                                                                                                                                                                                                                                                                                                                
          "event_data" => %{"course_id" => "c1", "student_id" => "s1"},                                                                                                                                                                                                                                                   
          "event_id" => "90441ac451c74a82ba0e643b510ad429",                                                                                                                                                                                                                                                               
          "event_metadata" => %{},                                                                                                                                                                                                                                                                                        
          "event_tags" => ["course:c1", "student:s1"],                                                                                                                                                                                                                                                                    
          "event_type" => "StudentSubscribedToCourse",                                                                                                                                                                                                                                                                    
          "store_position" => 10,                                                                                                                                                                                                                                                                                          
          "store_timestamp" => 1765242156981475                                                                                                                                                                                                                                                                           
        }                                                                                                                                                                                                                                                                                                                 
      ]
  """
  @spec from_tags(Fact.Types.event_tag() | [Fact.Types.event_tag(), ...]) ::
          {:ok, t()} | {:error, term()}
  def from_tags([]), do: {:error, :empty_tag_list}

  def from_tags(tags) when is_list(tags) do
    if tags |> Enum.all?(&is_binary/1) do
      event_tags = Enum.uniq(tags)

      fun =
        fn context ->
          matching_events =
            Enum.reduce(event_tags, :first, fn tag, acc ->
              matches_tag =
                Fact.IndexFile.read(context, {Fact.EventTagsIndexer, nil}, tag)
                |> Enum.into(MapSet.new())

              case acc do
                :first -> matches_tag
                _ -> MapSet.intersection(acc, matches_tag)
              end
            end)

          fn event_id ->
            MapSet.member?(matching_events, event_id)
          end
        end

      {:ok, fun}
    else
      {:error, :invalid_tag_criteria}
    end
  end

  def from_tags(tag), do: from_tags([tag])

  @doc """
  Creates a query which matches events tagged with all the supplied tags.

  Raises `ArgumentError` when no event tags are supplied.
    
  Raises `ArgumentError` if any supplied event tag is not a string.
  """
  @spec from_tags!(Fact.Types.event_tag() | [Fact.Types.event_tag(), ...]) :: t()
  def from_tags!(tags) do
    case from_tags(tags) do
      {:ok, query} ->
        query

      {:error, :empty_tag_list} ->
        raise ArgumentError, "must supply at least one event tag"

      {:error, :invalid_tag_criteria} ->
        raise ArgumentError, "all event tags must be strings"
    end
  end

  @doc """
  Creates a query which matches events with any of the supplied event types and returns it in a tuple.
    
  ## Examples
      
      iex> {:ok, query} = Fact.Query.from_types(["CourseDefined","StudentRegistered"])
      iex> Fact.read(:mydb, query) |> Enum.to_list()
      [
        %{                                                                                                                                                                                                                                                                                                                
          "event_data" => %{"capacity" => 10, "course_id" => "c1"},                                                                                                                                                                                                                                                       
          "event_id" => "a7f82f20b49549748a412797ef6b3c3d",                                                                                                                                                                                                                                                               
          "event_metadata" => %{},                                                                                                                                                                                                                                                                                        
          "event_tags" => ["course:c1"],                                                                                                                                                                                                                                                                                  
          "event_type" => "CourseDefined",                                                                                                                                                                                                                                                                                
          "store_position" => 1,                                                                                                                                                                                                                                                                                          
          "store_timestamp" => 1765222610917506                                                                                                                                                                                                                                                                           
        },
        %{                                                                                                                                                                                                                                                                                                                
          "event_data" => %{"student_id" => "s1"},                                                                                                                                                                                                                                                                        
          "event_id" => "ead3e5c6a78b493fade1b9fbad68ee35",                                                                                                                                                                                                                                                               
          "event_metadata" => %{},                                                                                                                                                                                                                                                                                        
          "event_tags" => ["student:s1"],                                                                                                                                                                                                                                                                                 
          "event_type" => "StudentRegistered",                                                                                                                                                                                                                                                                            
          "store_position" => 3,                                                                                                                                                                                                                                                                                         
          "store_timestamp" => 1765224325494777                                                                                                                                                                                                                                                                          
        }                                                                                                                                                                                                                                                                                                                 
      ]
  """
  @spec from_types(Fact.Types.event_type() | [Fact.Types.event_type(), ...]) ::
          {:ok, t()} | {:error, term()}
  def from_types([]), do: {:error, :empty_type_list}

  def from_types(types) when is_list(types) do
    if types |> Enum.all?(&is_binary/1) do
      event_types = Enum.uniq(types)

      fun =
        fn context ->
          matching_events =
            event_types
            |> Stream.flat_map(&Fact.IndexFile.read(context, {Fact.EventTypeIndexer, nil}, &1))
            |> Enum.into(MapSet.new())

          fn event_id ->
            MapSet.member?(matching_events, event_id)
          end
        end

      {:ok, fun}
    else
      {:error, :invalid_type_criteria}
    end
  end

  def from_types(type), do: from_types([type])

  @doc """
  Creates a query which matches events with any of the supplied event types

  Raises `ArgumentError` when no event types are supplied.
    
  Raises `ArgumentError` if any supplied event type is not a string.
  """
  @spec from_types!(Fact.Types.event_type() | [Fact.Types.event_type(), ...]) :: t()
  def from_types!(types) do
    case from_types(types) do
      {:ok, query} ->
        query

      {:error, :empty_type_list} ->
        raise ArgumentError, "must supply at least one event type"

      {:error, :invalid_type_criteria} ->
        raise ArgumentError, "all event types must be strings"
    end
  end
end
