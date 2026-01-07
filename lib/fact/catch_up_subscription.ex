defmodule Fact.CatchUpSubscription do
  @moduledoc """
  Behaviour and helper implementation for catch-up subscriptions.

  A catch-up subscription replays historical events from a source up to the
  current high-water mark, delivers them to a subscriber, and then switches
  into live mode to stream new events as they arrive.

  This module defines the callback contract and provides a `__using__/1`
  macro that implements the common GenServer lifecycle:

    • `:init` phase — the subscriber is monitored and the implementation
      subscribes to the event source.

    • The high-water mark is read and a replay is performed from the
      starting position up to that point.

    • Any events that arrive during replay are buffered and delivered
      after replay completes.

    • When catch-up finishes, the subscriber receives `:caught_up` and the
      subscription transitions to live mode.

  Implementations provide the mechanics for subscription and replay by
  defining the required callbacks, while optional hooks allow customization
  of state and position handling.
  """

  @callback subscribe(state :: term()) :: :ok
  @callback high_water_mark(state :: term()) :: Fact.event_position()
  @callback replay(
              state :: term(),
              from :: Fact.read_position_option(),
              to :: Fact.event_position(),
              deliver_fun :: (term() -> any())
            ) :: :ok
  @callback get_position(state :: term(), message :: term()) :: Fact.event_position()
  @callback on_init(state :: term()) :: term()

  defmacro __using__(_opts) do
    quote do
      use GenServer

      @behaviour Fact.CatchUpSubscription

      @impl true
      def init({database_id, subscriber, source, position}) do
        state = %{
          database_id: database_id,
          source: source,
          subscriber: subscriber,
          position: position,
          high_water_mark: nil,
          mode: :init,
          buffer: :gb_trees.empty(),
          schema: Fact.Event.Schema.get(database_id)
        }

        custom_state = __MODULE__.on_init(state)

        {:ok, custom_state, {:continue, :init_mode}}
      end

      @impl true
      def on_init(state), do: state

      @impl true
      def get_position(%{database_id: database_id, schema: schema} = _state, event) do
        event[schema.event_store_position]
      end

      defoverridable on_init: 1, get_position: 2

      @impl true
      def handle_continue(
            :init_mode,
            %{database_id: database_id, source: source, subscriber: subscriber} = state
          ) do
        Process.monitor(subscriber)

        # 1. Subscribe first
        __MODULE__.subscribe(state)
        # 2. Capture high water mark
        high_water_mark = __MODULE__.high_water_mark(state)
        # 3. Start replay
        send(self(), :replay)

        {:noreply, %{state | high_water_mark: high_water_mark, mode: :catchup}}
      end

      @impl true
      def handle_info(:replay, state) do
        __MODULE__.replay(
          state,
          min(state.position, state.high_water_mark),
          state.high_water_mark,
          fn record -> deliver(state.subscriber, record) end
        )

        flush_buffer(state)

        send(state.subscriber, :caught_up)

        {:noreply, %{state | mode: :live, buffer: :gb_trees.empty()}}
      end

      @impl true
      def handle_info({:DOWN, _ref, :process, pid, _reason}, %{subscriber: pid} = state) do
        {:stop, :normal, state}
      end

      defp buffer_or_deliver({_, event} = record, state) do
        pos = __MODULE__.get_position(state, event)

        cond do
          pos <= state.high_water_mark ->
            {:noreply, state}

          :catchup == state.mode ->
            {:noreply, %{state | buffer: :gb_trees.enter(pos, record, state.buffer)}}

          true ->
            deliver(state.subscriber, record)
            {:noreply, state}
        end
      end

      defp flush_buffer(state) do
        state.buffer
        |> :gb_trees.to_list()
        |> Enum.sort_by(fn {pos, _} -> pos end)
        |> Enum.each(fn {_, record} -> deliver(state.subscriber, record) end)
      end

      defp deliver(subscriber, record) do
        send(subscriber, {:record, record})
      end
    end
  end
end
