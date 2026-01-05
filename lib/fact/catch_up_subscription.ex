defmodule Fact.CatchUpSubscription do
  @callback subscribe(database_id :: Fact.Types.database_id(), event_source :: term()) :: :ok
  @callback high_water_mark(database_id :: Fact.Types.database_id(), event_source :: term()) ::
              Fact.Types.read_position()
  @callback replay(
              database_id :: Fact.Types.database_id(),
              event_source :: term(),
              from :: non_neg_integer(),
              to :: non_neg_integer,
              deliver_fun :: (term() -> any())
            ) :: :ok
  @callback get_position(
              database_id :: Fact.Types.database_id(),
              event_source :: term(),
              message :: term()
            ) :: non_neg_integer()

  defmacro __using__(_opts) do
    quote do
      use GenServer
      @behaviour Fact.CatchUpSubscriptionBehaviour

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
            %{database_id: database_id, source: source, subscriber: subscriber} = state
          ) do
        Process.monitor(subscriber)

        # 1. Subscribe first
        __MODULE__.subscribe(database_id, source)
        # 2. Capture high water mark
        high_water_mark = __MODULE__.high_water_mark(database_id, source)
        # 3. Start replay
        send(self(), :replay)

        {:noreply, %{state | high_water_mark: high_water_mark, mode: :catchup}}
      end

      @impl true
      def handle_info(:replay, state) do
        __MODULE__.replay(
          state.database_id,
          state.source,
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
        pos = __MODULE__.get_position(state.database_id, state.source, event)

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
        send(subscriber, {:event_record, record})
      end
    end
  end
end
