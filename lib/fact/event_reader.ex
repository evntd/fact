defmodule Fact.EventReader do
  @moduledoc """
  Provides a unified interface for reading events from the ledger, specific event streams, or event queries.
  """

  use Fact.EventKeys

  def read(instance, event_source, opts \\ [])

  def read(instance, :all, opts) do
    do_read(
      instance,
      fn -> Fact.EventLedger.stream!(instance, opts) end,
      @event_store_position,
      opts
    )
  end

  def read(instance, event_stream, opts) when is_binary(event_stream) do
    do_read(
      instance,
      fn ->
        Fact.EventIndexerManager.stream!(instance, Fact.EventStreamIndexer, event_stream, opts)
      end,
      @event_stream_position,
      opts
    )
  end

  def read(instance, %Fact.EventQuery{} = query, opts) do
    read(instance, [query], opts)
  end

  def read(instance, [%Fact.EventQuery{} | _] = query, opts) when is_list(query) do
    do_read(
      instance,
      fn -> Fact.EventQuery.execute(instance, query) end,
      @event_store_position,
      opts
    )
  end

  defp do_read(instance, read_strategy, compare_key, opts) do
    position = Keyword.get(opts, :position, :start)
    direction = Keyword.get(opts, :direction, :forward)
    count = Keyword.get(opts, :count, nil)

    cond do
      direction not in [:forward, :backward] ->
        raise ArgumentError,
              "expected :direction to be :forward or :backward, got: #{inspect(direction)}"

      not (position === :start or (is_integer(position) and position >= 0)) ->
        raise ArgumentError,
              "expected :position to be a non-negative integer or :start, got: #{inspect(position)}"

      not (is_nil(count) or (is_integer(count) and count >= 0)) ->
        raise ArgumentError,
              "expected :count to be a non-negative integer or nil, got: #{inspect(count)}"

      true ->
        position_is_out_of_range? =
          position_out_of_range_comparator(compare_key, direction, position)

        stream =
          read_strategy.()
          |> Stream.map(&Fact.EventStorage.read_event(instance, &1))
          |> Stream.drop_while(&position_is_out_of_range?.(&1))

        if is_integer(count) do
          Stream.take(stream, count)
        else
          stream
        end
    end
  end

  defp position_out_of_range_comparator(event_key, direction, position) do
    case {direction, position} do
      {_, :start} -> fn _ -> false end
      {:forward, pos} -> fn {_, event} -> event[event_key] <= pos end
      {:backward, pos} -> fn {_, event} -> event[event_key] > pos end
    end
  end
end
