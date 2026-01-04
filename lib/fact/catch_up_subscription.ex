defmodule Fact.CatchUpSubscription do
  @moduledoc """
  Provides a catch-up then live subscription to the event store or specified event stream.
    
  This ensures that a subscriber receives all historical events for a given event source
  before receiving any live events, preserving strict ordering guarantees.
    
  ## Messages
    
  Subscriber processes will receive:
    
  * `{:appended, {record_id, event_record}}` - for each event
  * `:caught_up` - sent when all events have been replayed

  ## Sources
    
  The `source` argument can be:

  * `:all` - will receive all events in the event store
  * `binary()` - a specific event stream
      
  ## Lifecycle

  1. Process starts and monitors the subscriber
  2. Subscribes to the PubSub topic for the source
  3. Captures the current high-water mark for the source
  4. Replays events from the requested start position
  5. Buffers any new events arriving during replay
  6. Flushes the buffer in order
  7. Transitions to live mode
  8. Terminates automatically when the subscriber exits.
  """

  use GenServer
  use Fact.Types

  require Logger

  @spec start_link(
          Fact.Context.t(),
          pid(),
          Fact.Types.read_event_source(),
          Fact.Types.read_position(),
          keyword()
        ) :: {:ok, pid()} | {:error, term()}
  def start_link(database_id, subscriber, source \\ :all, position \\ 0, opts \\ []) do
    GenServer.start_link(__MODULE__, {database_id, subscriber, source, position}, opts)
  end

  @impl true
  def init({database_id, subscriber, source, position}) do
    state = %{
      database_id: database_id,
      source: source,
      subscriber: subscriber,
      position: position,
      high_water_mark: nil,
      mode: :init,
      buffer: :gb_trees.empty()
    }

    {:ok, state, {:continue, :init_mode}}
  end

  @impl true
  def handle_continue(
        :init_mode,
        %{database_id: database_id, source: source} = state
      ) do
    Process.monitor(state.subscriber)

    # 1. Subscribe first
    Fact.EventPublisher.subscribe(database_id, source)
    # 2. Capture boundary
    high_water_mark = last_position(database_id, source)
    # 3. Start replay
    send(self(), :replay)

    {:noreply, %{state | high_water_mark: high_water_mark, mode: :catchup}}
  end

  @impl true
  def handle_info(:replay, state) do
    Fact.read(state.database_id, state.source,
      position: min(state.position, state.high_water_mark),
      direction: :forward,
      result_type: :record
    )
    |> Stream.take_while(fn {_, event} ->
      event_position(event, state.source) <= state.high_water_mark
    end)
    |> Enum.each(&deliver(&1, state))

    # Flush any buffered live events in order
    state.buffer
    |> :gb_trees.to_list()
    |> Enum.sort_by(fn {pos, _} -> pos end)
    |> Enum.each(fn {_, record} -> deliver(record, state) end)

    send(state.subscriber, :caught_up)

    {:noreply, %{state | mode: :live, buffer: :gb_trees.empty()}}
  end

  @impl true
  def handle_info({:appended, {_, event} = record}, state) do
    position = event_position(event, state.source)

    cond do
      position <= state.high_water_mark ->
        {:noreply, state}

      state.mode == :catchup ->
        buffer = :gb_trees.enter(position, record, state.buffer)
        {:noreply, %{state | buffer: buffer}}

      true ->
        deliver(record, state)
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, %{subscriber: pid} = state) do
    {:stop, :normal, state}
  end

  defp deliver(record, state) do
    send(state.subscriber, {:appended, record})
  end

  defp event_position(event, :all), do: event[@event_store_position]

  defp event_position(event, {:stream, event_stream}) when is_binary(event_stream),
    do: event[@event_stream_position]

  defp last_position(database_id, :all),
    do: Fact.Database.last_position(database_id)

  defp last_position(database_id, {:stream, event_stream}) when is_binary(event_stream),
    do: Fact.EventStreamIndexer.last_stream_position(database_id, event_stream)
end
