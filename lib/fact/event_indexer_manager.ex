defmodule Fact.EventIndexerManager do
  use GenServer
  use Fact.Types

  require Logger

  @topic "#{__MODULE__}"
  @type indexer_status :: :stopped | :starting | :started | :ready

  defstruct [
    :context,
    indexers: %{},
    indexer_specs: [],
    chase_position: 0,
    published_position: 0
  ]

  def start_link(opts) do
    {indexer_opts, genserver_opts} = Keyword.split(opts, [:context, :indexers])
    context = Keyword.fetch!(indexer_opts, :context)
    indexers = Keyword.fetch!(indexer_opts, :indexers)
    GenServer.start_link(__MODULE__, {context, indexers}, genserver_opts)
  end

  def ensure_indexer(%Fact.Context{} = context, indexer_id) do
    GenServer.call(Fact.Context.via(context, __MODULE__), {:ensure_indexer, indexer_id})
  end

  def start_indexer(%Fact.Context{} = context, child_spec) do
    GenServer.call(Fact.Context.via(context, __MODULE__), {:start_indexer, child_spec})
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

  def get_state(%Fact.Context{} = context) do
    GenServer.call(Fact.Context.via(context, __MODULE__), :get_state)
  end

  defp publish_indexed(%Fact.Context{} = context, position) do
    Phoenix.PubSub.broadcast(Fact.Context.pubsub(context), @topic, {:indexed, position})
  end

  @impl true
  def init({context, indexers}) do
    
    
    last_pos = Fact.Context.last_store_position(context)

    state = %__MODULE__{
      context: context,
      indexers: %{},
      indexer_specs: indexers,
      chase_position: last_pos,
      published_position: last_pos
    }

    Fact.EventPublisher.subscribe(context, :all)

    {:ok, state, {:continue, :start_indexers}}
  end

  @impl true
  def handle_continue(
        :start_indexers,
        %{indexers: indexers, indexer_specs: indexer_specs} = state
      ) do
    new_indexers =
      indexer_specs
      |> Enum.filter(fn {_mod, opts} -> Keyword.get(opts, :enabled, true) end)
      |> Enum.reduce(indexers, fn spec, acc ->
        indexer_key = get_indexer_id(spec)
        :ok = start_child_indexer(spec)
        Map.put(acc, indexer_key, %{pid: nil, status: :starting, waiters: [], position: 0})
      end)

    {:noreply, %{state | indexers: new_indexers}}
  end

  @impl true
  def handle_cast(
        {:start_child_indexer, spec},
        %__MODULE__{context: context, indexers: indexers} = state
      ) do
    indexer_id = get_indexer_id(spec)

    case Registry.lookup(Fact.Context.registry(context), indexer_id) do
      [] ->
        {mod, opts} = spec

        # subscribe to indexer messages
        Fact.EventIndexer.subscribe(context, indexer_id)

        # start the indexer
        {:ok, pid} =
          DynamicSupervisor.start_child(
            Fact.Context.via(context, Fact.EventIndexerSupervisor),
            {mod, {context, opts}}
          )

        info = %{
          pid: pid,
          status: :started,
          waiters: Map.get(indexers[indexer_id], :waiters, []),
          position: 0
        }

        new_indexers = Map.put(indexers, indexer_id, info)
        {:noreply, %__MODULE__{state | indexers: new_indexers}}

      [{_pid, _}] ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:indexer_ready, pid, indexer_key, checkpoint}, %__MODULE__{} = state) do
    # state book keeping, and extract waiting processes
    {waiters, indexers} =
      Map.get_and_update!(state.indexers, indexer_key, fn info ->
        waiters = Map.get(info, :waiters, [])
        {waiters, %{info | status: :ready, pid: pid, position: checkpoint}}
      end)

    # notify any process waiting on the indexer to be :ready
    Enum.each(waiters, &GenServer.reply(&1, {:ok, pid}))

    {:noreply, %__MODULE__{state | indexers: indexers}}
  end

  @impl true
  def handle_call(
        {:start_indexer, indexer_spec},
        _from,
        %{indexers: indexers} = state
      ) do
    indexer_id = get_indexer_id(indexer_spec)

    :ok = start_child_indexer(indexer_spec)

    new_indexers =
      Map.put_new(indexers, indexer_id, %{
        pid: nil,
        status: :starting,
        waiters: [],
        position: 0
      })

    {:reply, :ok, %{state | indexers: new_indexers}}
  end

  @impl true
  def handle_call(
        {:ensure_indexer, indexer_id},
        from,
        %__MODULE__{indexers: indexers} = state
      ) do
    case Map.get(indexers, indexer_id) do
      # Not started
      nil ->
        # indexer should be either the module, or a tuple {module, key}
        case normalize_indexer(indexer_id) do
          {:error, reason} ->
            {:reply, {:error, reason}, state}

          {:ok, {indexer_mod, maybe_indexer_key}} ->
            # lookup the indexer configuration by module
            config =
              state.indexer_specs
              |> Enum.find_value(fn {m, c} -> if m == indexer_mod, do: c end)

            unless config do
              # fail, if no indexer configuration exists, need the path for storing the index at a minimum
              {:reply, {:error, {:no_config, indexer_id}}, state}
            else
              start_opts =
                config
                |> maybe_put_key(maybe_indexer_key)

              indexer_spec = {indexer_mod, start_opts}

              :ok = start_child_indexer(indexer_spec)

              indexers =
                Map.put(state.indexers, indexer_id, %{
                  pid: nil,
                  status: :starting,
                  waiters: [from],
                  position: 0
                })

              {:noreply, %__MODULE__{state | indexers: indexers}}
            end
        end

      %{status: status, waiters: waiters} = info when status in [:starting, :started] ->
        indexers = Map.put(state.indexers, indexer_id, %{info | waiters: [from | waiters]})
        {:noreply, %__MODULE__{state | indexers: indexers}}

      %{status: :ready, pid: pid} ->
        {:reply, {:ok, pid}, state}
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
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

  defp normalize_indexer(indexer) do
    case indexer do
      {mod, key} when is_atom(key) ->
        {:ok, {mod, to_string(key)}}

      {mod, key} when is_binary(key) ->
        {:ok, {mod, key}}

      mod when is_atom(mod) ->
        {:ok, {mod, nil}}

      invalid_indexer ->
        {:error, {:invalid_indexer, invalid_indexer}}
    end
  end

  defp get_indexer_id({indexer_mod, indexer_opts}) do
    case Keyword.get(indexer_opts, :indexer_key) do
      nil -> indexer_mod
      indexer_key -> {indexer_mod, indexer_key}
    end
  end

  defp maybe_put_key(opts, nil), do: opts
  defp maybe_put_key(opts, key), do: Keyword.put(opts, :indexer_key, key)
end
