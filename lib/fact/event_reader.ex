defmodule Fact.EventReader do
  # TODO rename to Fact.EventStreamReader
  use Fact.EventKeys
  require Logger

  def read_all(opts \\ []) do
    from_position = Keyword.get(opts, :from_position, :start)
    direction = Keyword.get(opts, :direction, :forward)
    
    comparator =
      case {direction, from_position} do
        {_, :start} -> fn _ -> false end
        {:forward, from} -> fn event -> event[@event_store_position] <= from end
        {:backward, from} -> fn event -> event[@event_store_position] > from end
      end

    Fact.EventLedger.stream!(direction: direction)
    |> Stream.drop_while(&comparator.(&1))
  end

  def read_stream(event_stream, opts \\ []) do
    from_position = Keyword.get(opts, :from_position, :start)
    direction = Keyword.get(opts, :direction, :forward)
    
    comparator =
      case {direction, from_position} do
        {_, :start} -> fn _ -> false end
        {:forward, from} -> fn {_, pos} -> pos <= from end
        {:backward, from} -> fn {_, pos} -> pos > from end
      end

    Fact.EventIndexerManager.stream!(Fact.EventStreamIndexer, event_stream, direction: direction)
    |> Stream.with_index(1)
    |> Stream.drop_while(&comparator.(&1))
    |> Stream.map(fn {event, pos} ->
      # TODO: This is incorrect when reading backwards, it must be written into the event for preservation
      Map.put(event, @event_stream_position, pos)
    end)
  end

  def read_query(query, opts \\ [])
  def read_query(%Fact.EventQuery{} = query, opts), do: read_query([query], opts)

  def read_query([%Fact.EventQuery{} | _] = query, opts) when is_list(query) do
    from_position = Keyword.get(opts, :from_position, :start)
    direction = Keyword.get(opts, :direction, :forward)

    comparator =
      case {direction, from_position} do
        {_, :start} -> fn _ -> false end
        {:forward, from} -> fn event -> event[@event_store_position] <= from end
        {:backward, from} -> fn event -> event[@event_store_position] > from end
      end

    Fact.EventQuery.execute(query)
    |> Stream.drop_while(&comparator.(&1))
  end
end
