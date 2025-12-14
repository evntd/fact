defmodule Fact.CatchUpSubscription do
  @moduledoc """
  Provides a catch-up then live subscription to the event store or specified event stream.
    
  This ensures that a subscriber receives all historical events for a given event source
  before receiving any live events, preserving strict ordering guarantees.
    
  ## Messages
    
  Subscriber processes will receive:
    
  * `{:event_record, {record_id, event_record}}` - for each event
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
  use Fact.EventKeys

  require Logger

  @spec start_link(
          Fact.Types.instance_name(),
          pid(),
          :all | Fact.Types.event_stream(),
          :start | non_neg_integer(),
          keyword()
        ) :: {:ok, pid()} | {:error, term()}
  def start_link(instance, subscriber, source \\ :all, position \\ 0, opts \\ []) do
    GenServer.start_link(__MODULE__, {instance, subscriber, source, position}, opts)
  end

  @impl true
  def init({instance, subscriber, source, position}) do
    state = %{
      instance: instance,
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
        %{instance: instance, source: source} = state
      ) do
    Process.monitor(state.subscriber)

    # 1. Subscribe first
    Fact.EventPublisher.subscribe(instance, source)
    # 2. Capture boundary
    high_water_mark = last_position(instance, source)
    # 3. Start replay
    send(self(), :replay)

    {:noreply, %{state | high_water_mark: high_water_mark, mode: :catchup}}
  end

  @impl true
  def handle_info(:replay, state) do
    Fact.EventReader.read(state.instance, state.source,
      position: min(state.position, state.high_water_mark),
      direction: :forward
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
  def handle_info({:event_record, {_, event} = record}, state) do
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
    send(state.subscriber, {:event_record, record})
  end

  defp event_position(event, :all), do: event[@event_store_position]

  defp event_position(event, event_stream) when is_binary(event_stream),
    do: event[@event_stream_position]

  defp last_position(instance, :all), do: Fact.Storage.last_store_position(instance, :ledger)

  defp last_position(instance, event_stream) when is_binary(event_stream),
    do: Fact.EventStreamIndexer.last_stream_position(instance, event_stream)
end
