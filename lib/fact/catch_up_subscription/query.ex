defmodule Fact.CatchUpSubscription.Query do
  use Fact.CatchUpSubscription

  def start_link(options) do
    {opts, start_opts} =
      Keyword.split(options, [:database_id, :subscriber, :query_items, :position])

    database_id = Keyword.fetch!(opts, :database_id)
    query_items = Keyword.fetch!(opts, :query_items)
    subscriber = Keyword.fetch!(opts, :subscriber)
    position = Keyword.get(opts, :position, 0)

    GenServer.start_link(
      __MODULE__,
      {database_id, subscriber, {:query, query_items}, position},
      start_opts
    )
  end

  @impl true
  def subscribe(%{database_id: database_id, indexers: indexers}) do
    indexers
    |> Map.keys()
    |> Enum.each(fn {indexer_mod, indexer_key} = indexer_id ->
      Fact.Database.ensure_indexer(database_id, indexer_mod, key: indexer_key)
      Fact.EventIndexer.subscribe(database_id, indexer_id)
    end)
  end

  @impl true
  def on_init(state) do
    {:query, query_items} = state.source
    query_fun = Fact.QueryItem.to_function(query_items)
    sources = Fact.QueryItem.sources(query_items)

    indexers =
      sources
      |> Enum.map(&elem(&1, 1))
      |> MapSet.new()
      |> Map.new(fn k ->
        pos = Fact.IndexCheckpointFile.read(state.database_id, k)
        {k, %{high_water_mark: pos, indexed: pos}}
      end)

    Map.merge(state, %{
      indexers: indexers,
      sources: sources,
      query_fun: query_fun
    })
  end

  @impl true
  def high_water_mark(%{indexers: indexers}) do
    Map.values(indexers)
    |> Enum.map(&Map.get(&1, :high_water_mark))
    |> Enum.min()
  end

  @impl true
  def replay(
        %{database_id: database_id, query_fun: query_fun, schema: schema},
        from_pos,
        to_pos,
        deliver_fun
      ) do
    Fact.Database.read_query(database_id, query_fun, position: from_pos, result: :record)
    |> Stream.take_while(fn {_, event} ->
      event[schema.event_store_position] <= to_pos
    end)
    |> Enum.each(&deliver_fun.(&1))
  end

  @impl true
  def handle_info(
        {:indexed, indexer_id, %{position: position, record_id: record_id}},
        %{database_id: database_id, indexers: indexers, query_fun: query_fun} = state
      ) do
    new_indexers =
      update_in(indexers[indexer_id].indexed, fn
        nil -> position
        n when position > n -> position
        n -> n
      end)

    new_state = %{state | indexers: new_indexers}

    with true <- Enum.all?(new_indexers, fn {_k, %{indexed: i}} -> i >= position end),
         true <- query_fun.(database_id).(record_id) do
      buffer_or_deliver(Fact.Database.read_record(database_id, record_id), new_state)
    else
      _ ->
        {:noreply, new_state}
    end
  end

  @impl true
  def handle_info({:indexer_ready, _indexer_id, _checkpoint}, state) do
    {:noreply, state}
  end
end
