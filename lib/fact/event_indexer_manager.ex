defmodule Fact.EventIndexerManager do
  @moduledoc false

  use GenServer
  require Logger

  @type indexer_status :: :stopped | :starting | :started | :ready

  defstruct supervisor: nil, indexers: %{}

  def start_link(opts) do
    state = %__MODULE__{}
    opts = Keyword.put_new(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, state, opts)
  end

  def ensure_indexer(key) do
    GenServer.call(__MODULE__, {:ensure_indexer, key})
  end

  def index(event_paths) do
    indexers = :pg.get_members(:fact_indexers)

    _ =
      Enum.each(event_paths, fn event_path ->
        recorded_event = Fact.EventReader.read_event(event_path)
        Enum.each(indexers, &send(&1, {:index, recorded_event}))
      end)

    :ok
  end

  def last_position(indexer, key) do
    GenServer.call(__MODULE__, {:last_position, indexer, key})
  end

  def stream!(indexer, value, opts \\ []) do
    GenServer.call(__MODULE__, {:stream!, indexer, value, opts})
  end

  @impl true
  def init(state) do
    {:ok, supervisor} =
      DynamicSupervisor.start_link(strategy: :one_for_one, name: EventIndexerSupervisor)

    indexers =
      Application.get_env(:fact, :indexers)
      |> Enum.filter(fn config -> Keyword.get(config, :enabled, false) end)
      |> Enum.reduce(state.indexers, fn config, acc ->
        [mod: mod, opts: opts] = Keyword.take(config, [:mod, :opts])
        spec = {mod, opts}
        indexer_key = get_indexer_key(spec)
        GenServer.cast(self(), {:start_indexer, spec})
        Map.put(acc, indexer_key, %{pid: nil, status: :starting, waiters: []})
      end)

    {:ok, %__MODULE__{state | supervisor: supervisor, indexers: indexers}}
  end

  @impl true
  def handle_cast(
        {:start_indexer, spec},
        %__MODULE__{supervisor: supervisor, indexers: indexers} = state
      ) do
    indexer_key = get_indexer_key(spec)

    case Registry.lookup(Fact.EventIndexerRegistry, indexer_key) do
      [] ->
        {:ok, indexer} = DynamicSupervisor.start_child(supervisor, spec)

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
  def handle_call({:ensure_indexer, indexer}, from, state) do
    case Map.get(state.indexers, indexer) do
      # Not started
      nil ->
        # indexer should be either the module, or a tuple {module, key}
        case normalize_indexer(indexer) do
          {:error, reason} ->
            {:reply, {:error, reason}, state}

          {:ok, {mod, maybe_key}} ->
            # lookup the indexer configuration by module
            config =
              Application.get_env(:fact, :indexers, [])
              |> Enum.find(fn config -> Keyword.fetch!(config, :mod) == mod end)

            unless config do
              # fail, if no indexer configuration exists, need the path for storing the index at a minimum
              {:reply, {:error, {:no_config, indexer}}, state}
            else
              base_opts = Keyword.get(config, :opts, [])

              opts =
                base_opts
                |> Keyword.put(:name, {:via, Registry, {Fact.EventIndexerRegistry, indexer}})
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
  def handle_call({:last_position, indexer, value}, from, state) do
    case Map.get(state.indexers, indexer) do
      %{pid: pid} when is_pid(pid) ->
        :ok = GenServer.cast(pid, {:last_position, value, from})
        {:noreply, state}

      _ ->
        {:reply, {:error, {:not_started, indexer}}, state}
    end
  end

  @impl true
  def handle_call({:stream!, indexer, value, opts}, from, state) do
    case Map.get(state.indexers, indexer) do
      %{pid: pid} when is_pid(pid) ->
        :ok = GenServer.cast(pid, {:stream!, value, from, opts})
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

  @impl true
  def handle_info({:indexer_ready, pid, indexer_key}, state) do
    Logger.debug("Received :indexer_ready from #{inspect(indexer_key)} at #{inspect(pid)}")

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

  defp get_indexer_key({mod, opts}) do
    case Keyword.get(opts, :key) do
      nil -> mod
      key -> {mod, key}
    end
  end

  defp maybe_put_key(opts, nil), do: opts
  defp maybe_put_key(opts, key), do: Keyword.put(opts, :key, key)
end
