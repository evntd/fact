defmodule Fact.DataKeyIndexerManager do
  use GenServer
  require Logger

  defstruct [:index_dir, :supervisor]

  def start_link(opts) do
    {start_opts, index_opts} = Keyword.split(opts, [:debug, :name, :timeout, :spawn_opt, :hibernate_after])

    index_dir = Keyword.fetch!(index_opts, :index_dir)

    state = %__MODULE__{
      index_dir: index_dir
    }

    start_opts = Keyword.put_new(start_opts, :name, __MODULE__)

    GenServer.start_link(__MODULE__, state, start_opts)
  end

  def start_indexer(key) do
    GenServer.cast(__MODULE__, {:start_indexer, key})
  end

  def init(state) do
    {:ok, pid} = DynamicSupervisor.start_link(strategy: :one_for_one, name: DataKeyIndexerSupervisor)
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

  def handle_cast({:start_indexer, key}, %{index_dir: index_dir, supervisor: supervisor} = state) do

    case Registry.lookup(Fact.DataKeyIndexerRegistry, key) do
      [] ->
        spec = {Fact.DataKeyIndexer, key: key, index_dir: index_dir}
        {:ok, _pid} = DynamicSupervisor.start_child(supervisor, spec)
        {:noreply, state}

      [{_pid, _}] ->
        {:noreply, state}
    end
  end

end
