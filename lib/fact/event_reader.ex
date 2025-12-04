defmodule Fact.EventReader do
  @moduledoc """
  Provides a unified, consistent API for reading events from a Fact instance.

  `Fact.EventReader` supports three primary sources of events:

    * `:all` — reads from the global ledger index in event-store order.
    * an event stream name (binary) — reads events belonging to a specific stream.
    * one or more `%Fact.EventQuery{}` structs — executes the query engine and streams results.

  All read operations return a lazy `Stream` of `{record_id, event}` tuples, allowing callers
  to process large event sets efficiently without loading them fully into memory.

  ## Options

  The following options are accepted for all read strategies:

    * `:position` — starting position within the index.
      * `:start` (default) — begin at the start of the source.
      * non-negative integer — starting offset, interpreted relative to the index used:
        * For `:all` and queries: uses `@event_store_position`
        * For event streams: uses `@event_stream_position`

    * `:direction` — traversal direction (default: `:forward`)
      * `:forward` — increasing positions
      * `:backward` — decreasing positions

    * `:count` — maximum number of events to return (default: all)

  The reader validates these options and raises `ArgumentError` on invalid values.

  ## Returned Stream

  Each variant delegates to a `read_strategy/0` function that yields record IDs.
  These record IDs are resolved into full events via `Fact.Storage.read_event/2`,
  and the reader applies positional filtering and count limiting on top of that.

  Because a `Stream` is returned, callers must enumerate the stream (`Enum.to_list/1`,
  `Stream.run/1`, etc.) if side effects are desired.
  """

  use Fact.EventKeys

  @doc """
  Reads events from the ledger, index, or the events matching an `EventQuery`.
  """
  def read(instance, event_source, opts \\ [])

  def read(instance, :all, opts) do
    do_read(
      instance,
      fn -> Fact.Storage.read_index(instance, :ledger, opts) end,
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
          |> Stream.map(&Fact.Storage.read_event(instance, &1))
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
