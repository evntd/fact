defmodule Fact.EventStreamReader do
  @moduledoc false
  use Fact.EventKeys

  def read(event_source, opts \\ [])

  def read(:all, opts) do
    do_read(fn -> Fact.EventLedger.stream!(opts) end, opts)
  end

  def read(event_stream, opts) when is_binary(event_stream) do
    do_read(
      fn -> Fact.EventIndexerManager.stream!(Fact.EventStreamIndexer, event_stream, opts) end,
      opts
    )
  end

  def read(%Fact.EventQuery{} = query, opts) do
    read([query], opts)
  end

  def read([%Fact.EventQuery{} | _] = query, opts) when is_list(query) do
    do_read(fn -> Fact.EventQuery.execute(query) end, opts)
  end

  defp do_read(read_strategy, opts) do
    from_position = Keyword.get(opts, :from_position, :start)
    direction = Keyword.get(opts, :direction, :forward)
    compare = comparator(@event_store_position, direction, from_position)
    read_strategy.() |> Stream.drop_while(&compare.(&1))
  end

  defp comparator(event_key, direction, position) do
    case {direction, position} do
      {_, :start} -> fn _ -> false end
      {:forward, pos} -> &(&1[event_key] <= pos)
      {:backward, pos} -> &(&1[event_key] > pos)
    end
  end
end
