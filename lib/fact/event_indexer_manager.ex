defmodule Fact.EventIndexerManager do
  use GenServer
  use Fact.Types

  require Logger

  @topic "#{__MODULE__}"
  @type indexer_status :: :stopped | :starting | :started | :ready

  defstruct [
    :context,
    indexers: %{},
    chase_position: 0,
    published_position: 0
  ]

  def start_link(options) do
    {opts, start_opts} = Keyword.split(options, [:context])
    context = Keyword.fetch!(opts, :context)
    GenServer.start_link(__MODULE__, context, start_opts)
  end

  def ensure_indexer(%Fact.Context{} = context, indexer_module, options \\ []) do
    if function_exported?(indexer_module, :child_spec, 1) do
      child_spec = indexer_module.child_spec(Keyword.put(options, :context, context))
      GenServer.call(Fact.Context.via(context, __MODULE__), {:ensure_indexer, child_spec})
    else
      {:error, :invalid_indexer_module}
    end    
  end

  def start_indexer(%Fact.Context{} = context, indexer_module, options \\ []) do
    if function_exported?(indexer_module, :child_spec, 1) do
      child_spec = indexer_module.child_spec(Keyword.put(options, :context, context))
      GenServer.call(Fact.Context.via(context, __MODULE__), {:start_indexer, child_spec})
    else
      {:error, :invalid_indexer_module}
    end
  end

  def notify_ready(%Fact.Context{} = context, index, checkpoint) do
    GenServer.cast(
      Fact.Context.via(context, __MODULE__),
      {:indexer_ready, self(), index, checkpoint}
    )
  end

  def subscribe(%Fact.Context{} = context) do
    Phoenix.PubSub.subscribe(Fact.Context.pubsub(context), @topic)
  end

  defp publish_indexed(%Fact.Context{} = context, position) do
    Phoenix.PubSub.broadcast(Fact.Context.pubsub(context), @topic, {:indexed, position})
  end

  @impl true
  def init(context) do
    last_pos = Fact.Context.last_store_position(context)

    state = %__MODULE__{
      context: context,
      indexers: %{},
      chase_position: last_pos,
      published_position: last_pos
    }

    Fact.EventPublisher.subscribe(context, :all)

    {:ok, state}
  end

  @impl true
  def handle_cast(
        {:start_child_indexer, indexer_spec},
        %__MODULE__{context: context, indexers: indexers} = state
      ) do

    case Registry.lookup(Fact.Context.registry(context), indexer_spec.id) do
      [] ->
        # subscribe to indexer messages
        Fact.EventIndexer.subscribe(context, indexer_spec.id)

        # start the indexer
        {:ok, pid} = Supervisor.start_child(Fact.Context.supervisor(context), indexer_spec)
        info = %{
          pid: pid,
          status: :started,
          waiters: Map.get(indexers[indexer_spec.id], :waiters, MapSet.new()),
          position: 0
        }

        new_indexers = Map.put(indexers, indexer_spec.id, info)
        {:noreply, %__MODULE__{state | indexers: new_indexers}}

      [{_pid, _}] ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:indexer_ready, pid, indexer_id, checkpoint}, %__MODULE__{} = state) do
    # state book keeping, and extract waiting processes
    {waiters, indexers} =
      Map.get_and_update!(state.indexers, indexer_id, fn info ->
        waiters = Map.get(info, :waiters, MapSet.new())
        {waiters, %{info | status: :ready, pid: pid, position: checkpoint}}
      end)

    # notify any process waiting on the indexer to be :ready
    Enum.each(waiters, &GenServer.reply(&1, {:ok, indexer_id}))

    {:noreply, %__MODULE__{state | indexers: indexers}}
  end

  @impl true
  def handle_call({:start_indexer, indexer_spec},
        _from,
        %__MODULE__{indexers: indexers} = state
      ) do

    :ok = start_child_indexer(indexer_spec)

    new_indexers =
      Map.put_new(indexers, indexer_spec.id, %{
        pid: nil,
        status: :starting,
        waiters: MapSet.new(),
        position: 0
      })

    {:reply, :ok, %{state | indexers: new_indexers}}
  end
  
  @impl true
  def handle_call(
        {:ensure_indexer, indexer_spec},
        from,
        %__MODULE__{indexers: indexers} = state
      ) do
    case Map.get(indexers, indexer_spec.id) do
      # Not started
      nil ->
        
        :ok = start_child_indexer(indexer_spec)

        new_indexers =
            Map.put(state.indexers, indexer_spec.id, %{
              pid: nil,
              status: :starting,
              waiters: MapSet.new([from]),
              position: 0
            })

        {:noreply, %__MODULE__{state | indexers: new_indexers}}
        
      %{status: status, waiters: waiters} = info when status in [:starting, :started] ->
        indexers = Map.put(state.indexers, indexer_spec.id, %{info | waiters: MapSet.put(waiters, from)})
        {:noreply, %__MODULE__{state | indexers: indexers}}

      %{status: :ready, pid: pid} ->
        {:reply, {:ok, pid}, state}
    end
  end

  @impl true
  def handle_info(
        {:event_record, {_, %{@event_store_position => position} = _event} = _record},
        state
      ) do
    if position > state.chase_position do
      {:noreply, %{state | chase_position: position}}
    else
      Logger.warning(
        "[#{__MODULE__}] handle :event_record received event at #{position}, but high water mark is #{state.chase_position}"
      )

      {:noreply, state}
    end
  end

  @impl true
  def handle_info(
        {:indexed, indexer, %{position: pos}},
        %{context: context, indexers: indexers, published_position: pub_pos} = state
      ) do
    {_, new_indexers} =
      Map.get_and_update(indexers, indexer, fn %{position: cur_pos} = info ->
        new_pos = max(cur_pos, pos)
        {new_pos, %{info | position: new_pos}}
      end)

    min_pos = Enum.map(new_indexers, fn {_, %{position: p}} -> p end) |> Enum.min()

    if min_pos > pub_pos do
      publish_indexed(context, min_pos)
      {:noreply, %{state | indexers: new_indexers, published_position: min_pos}}
    else
      {:noreply, %{state | indexers: new_indexers}}
    end
  end

  defp start_child_indexer(indexer_spec) do
    GenServer.cast(self(), {:start_child_indexer, indexer_spec})
  end
end
