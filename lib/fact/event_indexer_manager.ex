defmodule Fact.EventIndexerManager do
  use GenServer
  import Fact.Names
  require Logger

  @type indexer_status :: :stopped | :starting | :started | :ready

  defstruct [:instance, indexers: %{}, indexer_specs: []]

  def start_link(opts) do
    {indexer_opts, genserver_opts} = Keyword.split(opts, [:instance, :indexers])
    instance = Keyword.fetch!(indexer_opts, :instance)
    indexers = Keyword.fetch!(indexer_opts, :indexers)
    genserver_opts = Keyword.put(genserver_opts, :name, via(instance, __MODULE__))
    GenServer.start_link(__MODULE__, {instance, indexers}, genserver_opts)
  end

  def ensure_indexer(instance, key) do
    GenServer.call(via(instance, __MODULE__), {:ensure_indexer, key})
  end

  def stream!(instance, indexer, value, direction \\ :forward) do
    GenServer.call(via(instance, __MODULE__), {:stream!, indexer, value, direction})
  end

  @impl true
  def init({instance, indexers}) do
    state = %__MODULE__{
      instance: instance,
      indexers: %{},
      indexer_specs: indexers
    }

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
        Map.put(acc, indexer_key, %{pid: nil, status: :starting, waiters: []})
      end)

    {:noreply, %{state | indexers: new_indexers}}
  end

  @impl true
  def handle_cast(
        {:start_indexer, spec},
        %{instance: instance, indexers: indexers} = state
      ) do
    indexer_key = get_indexer_key(spec)

    case Registry.lookup(registry(instance), indexer_key) do
      [] ->
        {:ok, indexer} =
          DynamicSupervisor.start_child(via(instance, Fact.EventIndexerSupervisor), spec)

        info = %{
          pid: indexer,
          status: :started,
          waiters: Map.get(indexers[indexer_key], :waiters, [])
        }

        new_indexers = Map.put(indexers, indexer_key, info)
        {:noreply, %__MODULE__{state | indexers: new_indexers}}

      [{_pid, _}] ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:indexer_ready, pid, indexer_key}, state) do
    # state book keeping, and extract waiting processes
    {waiters, indexers} =
      Map.get_and_update!(state.indexers, indexer_key, fn info ->
        waiters = Map.get(info, :waiters, [])
        {waiters, %{info | status: :ready, pid: pid}}
      end)

    # notify any process waiting on the indexer to be :ready
    Enum.each(waiters, &GenServer.reply(&1, {:ok, pid}))

    {:noreply, %__MODULE__{state | indexers: indexers}}
  end

  @impl true
  def handle_call(
        {:ensure_indexer, indexer},
        from,
        %{instance: instance, indexers: indexers} = state
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
              base_opts = Keyword.get(config, :opts, [])

              opts =
                base_opts
                |> Keyword.put_new(:instance, instance)
                |> Keyword.put(:name, via(instance, indexer))
                |> maybe_put_key(maybe_key)

              spec = {mod, opts}

              GenServer.cast(self(), {:start_indexer, spec})

              indexers =
                Map.put(state.indexers, get_indexer_key(spec), %{
                  pid: nil,
                  status: :starting,
                  waiters: [from]
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
  def handle_call({:stream!, indexer, value, direction}, from, state) do
    case Map.get(state.indexers, indexer) do
      %{pid: pid} when is_pid(pid) ->
        :ok = GenServer.cast(pid, {:stream!, value, from, direction})
        {:noreply, state}

      _ ->
        {:reply, {:error, {:not_started, indexer}}, state}
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
