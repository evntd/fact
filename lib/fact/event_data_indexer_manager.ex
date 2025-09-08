defmodule Fact.EventDataIndexerManager do
  use GenServer
  require Logger

  @type indexer_status :: :not_started | :building | :ready

  defstruct [
    :supervisor,  # The pid of the DynamicSupervisor
    :index_dir,   # The base path for event data indices
    indexers: %{} # %{ key => %{pid: pid, status: status}}
   ]

  def start_link(opts) do
    {start_opts, index_opts} = Keyword.split(opts, [:debug, :name, :timeout, :spawn_opt, :hibernate_after])

    index_dir = Keyword.fetch!(index_opts, :index_dir)

    state = %__MODULE__{
      index_dir: index_dir
    }

    start_opts = Keyword.put_new(start_opts, :name, __MODULE__)

    GenServer.start_link(__MODULE__, state, start_opts)
  end

  def status(key) do
    GenServer.call(__MODULE__, {:indexer_status, key})
  end

  def start_indexer(key) do
    GenServer.cast(__MODULE__, {:start_indexer, key})
  end

  def init(state) do
    {:ok, pid} = DynamicSupervisor.start_link(strategy: :one_for_one, name: EventDataIndexerSupervisor)
    {:ok, %__MODULE__{ state | supervisor: pid }, {:continue, :bootstrap}}
  end

  def handle_continue(:bootstrap, %{index_dir: index_dir} = state) do
    # All data indexers use their own directory where the indexing key is the name.
    # So just start one for each directory
    case File.ls(index_dir) do
      {:ok, keys} ->
        Enum.each(keys, &GenServer.cast(self(), {:start_indexer, &1}))
      {:error, _} ->
        :ok
    end

    {:noreply, state}
  end

  def handle_cast({:start_indexer, key}, %__MODULE__{index_dir: index_dir, supervisor: supervisor, indexers: indexers} = state) do

    case Registry.lookup(Fact.EventDataIndexerRegistry, key) do
      [] ->
        spec = {Fact.EventDataIndexer, key: key, index_dir: index_dir}
        {:ok, pid} = DynamicSupervisor.start_child(supervisor, spec)
        new_indexers = Map.put(indexers, key, %{pid: pid, status: :building})
        {:noreply, %__MODULE__{ state | indexers: new_indexers }}

      [{_pid, _}] ->
        {:noreply, state}
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

    Logger.debug("#{__MODULE__} received :indexer_ready for #{key} from #{inspect(pid)}")

    indexers = Map.update!(state.indexers, key, fn info ->
      %{info | status: :ready}
    end)

    {:noreply, %__MODULE__{ state | indexers: indexers } }
  end

end
