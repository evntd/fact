defmodule Fact.CatchUpSubscription.DebugSubscriber do
  use GenServer

  require Logger

  def subscribe_all(database_id, position \\ 0) do
    GenServer.start_link(__MODULE__, {database_id, :all, position})
  end

  def subscribe_stream(database_id, stream, position \\ 0) do
    GenServer.start_link(__MODULE__, {database_id, {:stream, stream}, position})
  end

  def subscribe_index(database_id, indexer_id, index, position \\ 0) do
    GenServer.start_link(__MODULE__, {database_id, {:index, indexer_id, index}, position})
  end

  @impl true
  def init({database_id, source, position}) do
    state = %{
      database_id: database_id,
      source: source,
      position: position
    }

    {:ok, state, {:continue, :subscribe}}
  end

  @impl true
  def handle_continue(:subscribe, state) do
    case state.source do
      :all ->
        Fact.CatchUpSubscription.All.start_link(
          database_id: state.database_id,
          subscriber: self(),
          position: state.position
        )

      {:stream, stream} ->
        Fact.CatchUpSubscription.Stream.start_link(
          database_id: state.database_id,
          subscriber: self(),
          stream: stream,
          position: state.position
        )

      {:index, indexer_id, index} ->
        Fact.CatchUpSubscription.Index.start_link(
          database_id: state.database_id,
          subscriber: self(),
          indexer_id: indexer_id,
          index: index,
          position: state.position
        )

      _ ->
        Logger.warning("failed to subscribe")
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:event_record, record}, state) do
    Logger.info("#{__MODULE__}: #{inspect(elem(record, 1))}")
    {:noreply, state}
  end

  @impl true
  def handle_info(:caught_up, state) do
    Logger.info("#{__MODULE__}: CAUGHT UP")
    {:noreply, state}
  end
end
