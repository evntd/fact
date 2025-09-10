defmodule Fact.EventDataIndexerManager do
  use GenServer
  alias Fact.Paths
  require Logger

  @type indexer_status :: :not_started | :building | :ready

  defstruct [
    :supervisor,  # The pid of the DynamicSupervisor
    indexers: %{} # %{ key => %{pid: pid, status: status, waiting: []}}
   ]

  def start_link(opts \\ []) do

    state = %__MODULE__{
      supervisor: nil,
      indexers: %{}
    }

    opts = Keyword.put_new(opts, :name, __MODULE__)

    GenServer.start_link(__MODULE__, state, opts)
  end

  def status(key) do
    GenServer.call(__MODULE__, {:indexer_status, key})
  end

  def start_indexer(key) do
    GenServer.cast(__MODULE__, {:start_indexer, key})
  end

  def ensure_indexer(key) do
    GenServer.call(__MODULE__, {:ensure_indexer, to_string(key)})
  end

  def init(state) do
    {:ok, pid} = DynamicSupervisor.start_link(strategy: :one_for_one, name: EventDataIndexerSupervisor)
    {:ok, %__MODULE__{ state | supervisor: pid }, {:continue, :bootstrap}}
  end

  def handle_continue(:bootstrap, state) do
    # All data indexers use their own directory where the indexing key is the name.
    # So just start one for each directory
    index_dir = Paths.index(:event_data)
    case File.ls(index_dir) do
      {:ok, keys} ->
        new_indexers =
          Enum.reduce(keys, state.indexers, fn key, acc ->
            GenServer.cast(self(), {:start_indexer, key})
            Map.put(acc, key, %{pid: nil, status: :building, waiters: []})
          end)

        {:noreply, %__MODULE__{state | indexers: new_indexers}}

      {:error, _} ->
        {:noreply, state}
    end
  end

  def handle_cast({:start_indexer, key}, %__MODULE__{supervisor: supervisor, indexers: indexers} = state) do

    case Registry.lookup(Fact.EventDataIndexerRegistry, key) do
      [] ->
        spec = {Fact.EventDataIndexer, key: key}
        {:ok, pid} = DynamicSupervisor.start_child(supervisor, spec)

        info = %{
          pid: pid,
          status: :building,
          waiters: Map.get(indexers[key], :waiters, [])
        }

        new_indexers = Map.put(indexers, key, info)
        {:noreply, %__MODULE__{ state | indexers: new_indexers }}

      [{_pid, _}] ->
        {:noreply, state}
    end
  end

  def handle_call({:ensure_indexer, key}, from, %__MODULE__{indexers: indexers} = state) do
    case Map.get(indexers, key) do
      # Not started
      nil ->
        GenServer.cast(self(), {:start_indexer, key})
        new_indexers = Map.put(indexers, key, %{pid: nil, status: :building, waiters: [from]})
        {:noreply, %__MODULE__{ state | indexers: new_indexers}}

      # Already building - add caller to the waiters list
      %{status: :building, waiters: waiters} = info ->
        new_indexers = Map.put(state.indexers, key, %{info | waiters: [from | waiters]})
        {:noreply, %__MODULE__{ state | indexers: new_indexers}}

      # Ready to rock
      %{status: :ready, pid: pid} ->
        {:reply, {:ok, pid}, state}
    end
  end

  def handle_call({:indexer_status, key}, _from, %__MODULE__{indexers: indexers} = state) do
    status =
      case Map.get(indexers, key) do
        nil -> :not_started
        %{status: s} -> s
      end

    {:reply, status, state}
  end

  def handle_info({:indexer_ready, pid, key}, state) do

    Logger.debug("#{__MODULE__} received :indexer_ready from Elixir.Fact.EventDataIndexer[#{key}] at #{inspect(pid)}")

    {waiters, indexers} =
      Map.get_and_update!(state.indexers, key, fn info ->
        waiters = Map.get(info, :waiters, [])
        {waiters, %{info | status: :ready, pid: pid}}
      end)

    Enum.each(waiters, fn from ->
      GenServer.reply(from, {:ok, pid})
    end)

    {:noreply, %__MODULE__{ state | indexers: indexers } }
  end

end
