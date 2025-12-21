defmodule Fact.EventIndexerManager do
  use GenServer
  use Fact.Types

  require Logger

  @topic "#{__MODULE__}"
  @type indexer_status :: :stopped | :starting | :started | :ready

  defstruct [
    :instance,
    indexers: %{},
    indexer_specs: [],
    chase_position: 0,
    published_position: 0
  ]

  def start_link(opts) do
    {indexer_opts, genserver_opts} = Keyword.split(opts, [:instance, :indexers])
    instance = Keyword.fetch!(indexer_opts, :instance)
    indexers = Keyword.fetch!(indexer_opts, :indexers)
    GenServer.start_link(__MODULE__, {instance, indexers}, genserver_opts)
  end

  def ensure_indexer(%Fact.Instance{} = instance, key) do
    GenServer.call(Fact.Instance.event_indexer_manager(instance), {:ensure_indexer, key})
  end

  def stream!(%Fact.Instance{} = instance, indexer, value, direction \\ :forward) do
    GenServer.call(
      Fact.Instance.event_indexer_manager(instance),
      {:stream!, indexer, value, direction}
    )
  end

  def notify_ready(%Fact.Instance{} = instance, index, checkpoint) do
    GenServer.cast(
      Fact.Instance.event_indexer_manager(instance),
      {:indexer_ready, self(), index, checkpoint}
    )
  end

  def subscribe(%Fact.Instance{} = instance) do
    Phoenix.PubSub.subscribe(Fact.Instance.pubsub(instance), @topic)
  end

  def get_state(%Fact.Instance{} = instance) do
    GenServer.call(Fact.Instance.event_indexer_manager(instance), :get_state)
  end

  defp publish_indexed(%Fact.Instance{} = instance, position) do
    Phoenix.PubSub.broadcast(Fact.Instance.pubsub(instance), @topic, {:indexed, position})
  end

  @impl true
  def init({instance, indexers}) do
    last_pos = Fact.Storage.last_store_position(instance)

    state = %__MODULE__{
      instance: instance,
      indexers: %{},
      indexer_specs: indexers,
      chase_position: last_pos,
      published_position: last_pos
    }

    Fact.EventPublisher.subscribe(instance, :all)

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
        indexer_key = get_indexer_key(spec)
        GenServer.cast(self(), {:start_indexer, spec})
        Map.put(acc, indexer_key, %{pid: nil, status: :starting, waiters: [], position: 0})
      end)

    {:noreply, %{state | indexers: new_indexers}}
  end

  @impl true
  def handle_cast(
        {:start_indexer, spec},
        %__MODULE__{instance: instance, indexers: indexers} = state
      ) do
    indexer = get_indexer_key(spec)

    case Registry.lookup(Fact.Instance.registry(instance), indexer) do
      [] ->
        {mod, opts} = spec

        # subscribe to indexer messages
        Fact.EventIndexer.subscribe(instance, indexer)

        # start the indexer
        {:ok, pid} =
          DynamicSupervisor.start_child(
            Fact.Instance.event_indexer_supervisor(instance),
            {mod, Keyword.put(opts, :instance, instance)}
          )

        # setup some book keeping state for the indexer
        info = %{
          pid: pid,
          status: :started,
          waiters: Map.get(indexers[indexer], :waiters, []),
          position: 0
        }

        new_indexers = Map.put(indexers, indexer, info)
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
        {:ensure_indexer, indexer},
        from,
        %__MODULE__{instance: instance, indexers: indexers} = state
      ) do
    case Map.get(indexers, indexer) do
      # Not started
      nil ->
        # indexer should be either the module, or a tuple {module, key}
        case normalize_indexer(indexer) do
          {:error, reason} ->
            {:reply, {:error, reason}, state}

          {:ok, {mod, maybe_key}} ->
            # lookup the indexer configuration by module
            config =
              state.indexer_specs
              |> Enum.find_value(fn {m, c} -> if m == mod, do: c end)

            unless config do
              # fail, if no indexer configuration exists, need the path for storing the index at a minimum
              {:reply, {:error, {:no_config, indexer}}, state}
            else
              opts =
                config
                |> Keyword.put(:name, Fact.Instance.via(instance, indexer))
                |> maybe_put_key(maybe_key)

              spec = {mod, opts}

              GenServer.cast(self(), {:start_indexer, spec})

              indexers =
                Map.put(state.indexers, get_indexer_key(spec), %{
                  pid: nil,
                  status: :starting,
                  waiters: [from],
                  position: 0
                })

              {:noreply, %__MODULE__{state | indexers: indexers}}
            end
        end

      %{status: status, waiters: waiters} = info when status in [:starting, :started] ->
        indexers = Map.put(state.indexers, indexer, %{info | waiters: [from | waiters]})
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
  def handle_call({:stream!, indexer, value, direction}, from, state) do
    case Map.get(state.indexers, indexer) do
      %{pid: pid} when is_pid(pid) ->
        :ok = GenServer.cast(pid, {:stream!, value, from, direction})
        {:noreply, state}

      _ ->
        {:reply, {:error, {:not_started, indexer}}, state}
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
        {:indexed, %{indexer: indexer, position: pos}},
        %{instance: instance, indexers: indexers, published_position: pub_pos} = state
      ) do
    {_, new_indexers} =
      Map.get_and_update(indexers, indexer, fn %{position: cur_pos} = info ->
        new_pos = max(cur_pos, pos)
        {new_pos, %{info | position: new_pos}}
      end)

    min_pos = Enum.map(new_indexers, fn {_, %{position: p}} -> p end) |> Enum.min()

    if min_pos > pub_pos do
      publish_indexed(instance, min_pos)
      {:noreply, %{state | indexers: new_indexers, published_position: min_pos}}
    else
      {:noreply, %{state | indexers: new_indexers}}
    end
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

  defp get_indexer_key({mod, opts}) do
    case Keyword.get(opts, :key) do
      nil -> mod
      key -> {mod, key}
    end
  end

  defp maybe_put_key(opts, nil), do: opts
  defp maybe_put_key(opts, key), do: Keyword.put(opts, :key, key)
end
