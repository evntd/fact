defmodule Fact.CatchUpSubscription.Index do
  @moduledoc """
  Catch-up subscription for a single index value.

  This subscription replays and streams events that appear in the given index,
  starting from the configured position and continuing in live mode once caught up.
  """
  use Fact.CatchUpSubscription

  def start_link(options) do
    {opts, start_opts} =
      Keyword.split(options, [:database_id, :subscriber, :indexer_id, :index, :position])

    database_id = Keyword.fetch!(opts, :database_id)
    indexer_id = Keyword.fetch!(opts, :indexer_id)
    index = Keyword.fetch!(opts, :index)
    subscriber = Keyword.get(opts, :subscriber, self())
    position = Keyword.get(opts, :position, :start)

    GenServer.start_link(
      __MODULE__,
      {database_id, subscriber, {:index, indexer_id, index}, position},
      start_opts
    )
  end

  @impl true
  @doc false
  def subscribe(%{database_id: database_id, source: {:index, indexer_id, _index}}) do
    Fact.EventIndexer.subscribe(database_id, indexer_id)
  end

  @impl true
  @doc false
  def high_water_mark(%{database_id: database_id, source: {:index, indexer_id, _index}}) do
    Fact.IndexCheckpointFile.read(database_id, indexer_id)
  end

  @impl true
  @doc false
  def replay(
        %{database_id: database_id, schema: schema, source: {:index, indexer_id, index}},
        from_pos,
        to_pos,
        deliver_fun
      ) do
    Fact.Database.read_index(database_id, indexer_id, index,
      position: from_pos,
      result: :record
    )
    |> Stream.take_while(fn {_, event} ->
      event[schema.event_store_position] <= to_pos
    end)
    |> Enum.each(&deliver_fun.(&1))
  end

  @impl true
  @doc false
  def handle_info({:indexed, indexer_id, info}, %{source: {:index, indexer_id, index}} = state) do
    if index in info.index_values do
      record = Fact.Database.read_record(state.database_id, info.record_id)
      buffer_or_deliver(record, state)
    else
      {:noreply, state}
    end
  end

  @impl true
  @doc false
  def handle_info({:indexer_ready, _indexer_id, _checkpoint}, state) do
    {:noreply, state}
  end
end
