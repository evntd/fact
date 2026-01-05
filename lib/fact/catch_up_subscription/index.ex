defmodule Fact.CatchUpSubscription.Index do
  use Fact.CatchUpSubscription

  def start_link(options) do
    {opts, start_opts} =
      Keyword.split(options, [:database_id, :subscriber, :indexer_id, :index, :position])

    database_id = Keyword.fetch!(opts, :database_id)
    indexer_id = Keyword.fetch!(opts, :indexer_id)
    index = Keyword.fetch!(opts, :index)
    subscriber = Keyword.fetch!(opts, :subscriber)
    position = Keyword.get(opts, :position, 0)

    GenServer.start_link(
      __MODULE__,
      {database_id, subscriber, {:index, indexer_id, index}, position},
      start_opts
    )
  end

  @impl true
  def subscribe(database_id, {:index, indexer_id, _index} = _source) do
    Fact.EventIndexer.subscribe(database_id, indexer_id)
  end

  @impl true
  def get_position(database_id, {:index, _indexer_id, _index} = _source, event) do
    with {:ok, context} <- Fact.Registry.get_context(database_id) do
      Fact.Event.Schema.get_event_store_position(context, event)
    end
  end

  @impl true
  def high_water_mark(database_id, {:index, indexer_id, _index} = _source) do
    with {:ok, context} <- Fact.Registry.get_context(database_id) do
      Fact.IndexCheckpointFile.read(context, indexer_id)
    end
  end

  @impl true
  def replay(database_id, {:index, indexer_id, index} = _source, from_pos, to_pos, deliver_fun) do
    with {:ok, context} <- Fact.Registry.get_context(database_id) do
      Fact.Database.read_index(database_id, indexer_id, index,
        position: from_pos,
        result_type: :record
      )
      |> Stream.take_while(fn {_, event} ->
        Fact.Event.Schema.get_event_store_position(context, event) <= to_pos
      end)
      |> Enum.each(&deliver_fun.(&1))
    end
  end

  @impl true
  def handle_info({:indexed, indexer_id, info}, %{source: {:index, indexer_id, index}} = state) do
    if index in info.index_values do
      record = Fact.Database.read_record(state.database_id, info.record_id)
      buffer_or_deliver(record, state)
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info({:indexer_ready, _indexer_id, _checkpoint}, state) do
    {:noreply, state}
  end
end
