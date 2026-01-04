defmodule Fact.Database do
  use GenServer

  require Logger

  defstruct [
    :chase_pos,
    :database_id,
    :indexers,
    :lock,
    :published_pos
  ]

  @topic "#{__MODULE__}"

  def ensure_indexer(database_id, indexer_module, options \\ []) do
    if function_exported?(indexer_module, :child_spec, 1) do
      child_spec = indexer_module.child_spec(Keyword.put(options, :database_id, database_id))
      GenServer.call(Fact.Context.via(database_id, __MODULE__), {:ensure_indexer, child_spec})
    else
      {:error, :invalid_indexer_module}
    end
  end

  def last_position(database_id) do
    with {:ok, context} <- Fact.Registry.get_context(database_id),
         stream <- Fact.LedgerFile.read(context, direction: :backward, position: :end, count: 1),
         event <- Fact.RecordFile.read_event(context, stream |> Enum.at(0)) do
      Fact.RecordFile.Schema.get_event_store_position(context, event)
    end
  end

  defp publish_indexed(database_id, position) do
    Phoenix.PubSub.broadcast(Fact.Context.pubsub(database_id), @topic, {:indexed, position})
  end

  def read_event(database_id, record_id) do
    with {:ok, context} <- Fact.Registry.get_context(database_id) do
      Fact.RecordFile.read_event(context, record_id)
    end
  end
  
  def read_index(database_id, indexer_id, index, read_opts) do
    with {:ok, context} <- Fact.Registry.get_context(database_id) do
      map_read_results = to_result_type(context, Keyword.get(read_opts, :result_type, :event))
      map_read_results.(Fact.IndexFile.read(context, indexer_id, index, read_opts))
    end
  end

  def read_ledger(database_id, read_opts) do
    with {:ok, context} <- Fact.Registry.get_context(database_id) do
      map_read_results = to_result_type(context, Keyword.get(read_opts, :result_type, :event))
      map_read_results.(Fact.LedgerFile.read(context, read_opts))
    end
  end
  
  def read_query(database_id, query_fun, read_opts) do
    with {:ok, context} <- Fact.Registry.get_context(database_id) do
      {maybe_count, read_ledger_opts} = Keyword.split(read_opts, [:count])
      predicate = query_fun.(context)

      stream =
        Fact.LedgerFile.read(context, read_ledger_opts)
        |> Stream.filter(&predicate.(&1))

      map_read_results = to_result_type(context, Keyword.get(read_opts, :result_type, :event))
      case Keyword.get(maybe_count, :count, :all) do
        :all ->
          map_read_results.(stream)
        n ->
          map_read_results.(Stream.take(stream, n))
      end
    end
  end

  def read_record(database_id, record_id) do
    with {:ok, context} <- Fact.Registry.get_context(database_id) do
      Fact.RecordFile.read(context, record_id)
    end
  end
  
  defp start_child_indexer(child_spec) do
    GenServer.cast(self(), {:start_child_indexer, child_spec})
  end

  def start_indexer(database_id, indexer_module, options \\ []) do
    if function_exported?(indexer_module, :child_spec, 1) do
      child_spec = indexer_module.child_spec(Keyword.put(options, :database_id, database_id))
      GenServer.call(Fact.Context.via(database_id, __MODULE__), {:start_indexer, child_spec})
    else
      {:error, :invalid_indexer_module}
    end
  end

  def start_link(options) do
    {opts, start_opts} = Keyword.split(options, [:database_id])

    case Keyword.get(opts, :database_id) do
      nil ->
        {:error, :database_context_required}

      database_id ->
        GenServer.start_link(__MODULE__, database_id, start_opts)
    end
  end

  def subscribe(%Fact.Context{} = context) do
    Phoenix.PubSub.subscribe(Fact.Context.pubsub(context), @topic)
  end

  defp to_result_type(context, result_type) do
    case result_type do
      :event ->
        &Stream.map(&1, fn record_id -> elem(Fact.RecordFile.read(context, record_id), 1) end)

      :record ->
        &Stream.map(&1, fn record_id -> Fact.RecordFile.read(context, record_id) end)

      :record_id ->
        & &1
    end
  end

  @impl true
  def handle_call({:ensure_indexer, child_spec}, from, %__MODULE__{indexers: indexers} = state) do
    case Map.get(indexers, child_spec.id) do
      # Not started
      nil ->
        :ok = start_child_indexer(child_spec)

        new_indexers =
          Map.put(state.indexers, child_spec.id, %{
            pid: nil,
            status: :starting,
            waiters: MapSet.new([from]),
            position: 0
          })

        {:noreply, %__MODULE__{state | indexers: new_indexers}}

      %{status: status, waiters: waiters} = info when status in [:starting, :started] ->
        new_indexers =
          Map.put(state.indexers, child_spec.id, %{info | waiters: MapSet.put(waiters, from)})

        {:noreply, %__MODULE__{state | indexers: new_indexers}}

      %{status: :ready, pid: pid} ->
        {:reply, {:ok, pid}, state}
    end
  end

  @impl true
  def handle_call({:start_indexer, child_spec}, _from, %__MODULE__{indexers: indexers} = state) do
    :ok = start_child_indexer(child_spec)

    new_indexers =
      Map.put_new(indexers, child_spec.id, %{
        pid: nil,
        status: :starting,
        waiters: MapSet.new(),
        position: 0
      })

    {:reply, :ok, %{state | indexers: new_indexers}}
  end

  @impl true
  def handle_cast(
        {:start_child_indexer, child_spec},
        %__MODULE__{database_id: database_id, indexers: indexers} = state
      ) do
    case Registry.lookup(Fact.Context.registry(database_id), child_spec.id) do
      [] ->
        # subscribe to indexer messages
        Fact.EventIndexer.subscribe(database_id, child_spec.id)

        # start the indexer
        {:ok, pid} = Supervisor.start_child(Fact.Context.supervisor(database_id), child_spec)

        info = %{
          pid: pid,
          status: :started,
          waiters: Map.get(indexers[child_spec.id], :waiters, MapSet.new()),
          position: 0
        }

        new_indexers = Map.put(indexers, child_spec.id, info)
        {:noreply, %__MODULE__{state | indexers: new_indexers}}

      [{_pid, _}] ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(
        {:appended, {_, event}},
        %__MODULE__{database_id: database_id, chase_pos: chase_pos} = state
      ) do
    with {:ok, context} <- Fact.Registry.get_context(database_id) do
      pos = Fact.RecordFile.Schema.get_event_store_position(context, event)

      if pos > chase_pos do
        {:noreply, %{state | chase_pos: pos}}
      else
        Logger.warning(
          "[#{__MODULE__}] handle :appended received event at #{pos}, but high water mark is #{chase_pos}"
        )

        {:noreply, state}
      end
    end
  end

  @impl true
  def handle_info(
        {:indexed, indexer, %{position: pos}},
        %{database_id: database_id, indexers: indexers, published_pos: published_pos} = state
      ) do
    {_, new_indexers} =
      Map.get_and_update(indexers, indexer, fn %{position: cur_pos} = info ->
        new_pos = max(cur_pos, pos)
        {new_pos, %{info | position: new_pos}}
      end)

    min_pos = Enum.map(new_indexers, fn {_, %{position: p}} -> p end) |> Enum.min()

    if min_pos > published_pos do
      publish_indexed(database_id, min_pos)
      {:noreply, %{state | indexers: new_indexers, published_pos: min_pos}}
    else
      {:noreply, %{state | indexers: new_indexers}}
    end
  end

  @impl true
  def handle_info({:indexer_ready, indexer_id, checkpoint}, %__MODULE__{} = state) do
    # state book keeping, and extract waiting processes
    {waiters, indexers} =
      Map.get_and_update!(state.indexers, indexer_id, fn info ->
        waiters = Map.get(info, :waiters, MapSet.new())
        {waiters, %{info | status: :ready, position: checkpoint, waiters: MapSet.new()}}
      end)

    # notify any process waiting on the indexer to be :ready
    Enum.each(waiters, &GenServer.reply(&1, {:ok, indexer_id}))

    {:noreply, %__MODULE__{state | indexers: indexers}}
  end

  @impl true
  def init(database_id) do
    case Fact.Lock.acquire(database_id, :run) do
      {:ok, lock} ->
        last_pos = last_position(database_id)

        state = %__MODULE__{
          chase_pos: last_pos,
          database_id: database_id,
          indexers: %{},
          lock: lock,
          published_pos: last_pos
        }

        Fact.EventPublisher.subscribe(database_id, :all)

        {:ok, state}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def terminate(_reason, %{database_id: database_id, lock: lock}) do
    Fact.Lock.release(database_id, lock)
    :ok
  end
end
