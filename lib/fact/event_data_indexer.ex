defmodule Fact.EventDataIndexer do
  use GenServer
  alias Fact.Paths
  require Logger

  defstruct [
    :index_dir,
    :key,
    :checkpoint_file]

  def start_link(opts) do
    {start_opts, index_opts} = Keyword.split(opts, [:debug, :name, :timeout, :spawn_opt, :hibernate_after])

    key = Keyword.fetch!(index_opts, :key)

    state = %__MODULE__{
      key: key,
      index_dir: Paths.index({:event_data, key}),
      checkpoint_file: Paths.index_checkpoint({:event_data, key})
    }

    start_opts = Keyword.put_new(start_opts, :name, via_tuple(key))

    GenServer.start_link(__MODULE__, state, start_opts)
  end

  defp via_tuple(key), do: {:via, Registry, {Fact.EventDataIndexerRegistry, key}}

  def init(%{key: key} = state) do
    Logger.debug("#{__MODULE__}[#{key}] init called")

    index_dir = Paths.index({:event_data, key})
    unless File.exists?(index_dir) do
      File.mkdir_p!(index_dir)
      Logger.debug("created: #{index_dir}")
    end

    {:ok, state, {:continue, :rebuild_and_join}}
  end

  def handle_continue(:rebuild_and_join, %{key: key} = state) do
    last_pos = load_checkpoint(state)

    Logger.debug("#{__MODULE__}[#{key}] building index from #{last_pos}")
    
    Fact.EventReader.read_all(from_position: last_pos)
    |> Enum.each(fn event ->
      append_to_index(state, event)
      save_checkpoint(state, event)
    end)
    
    Logger.debug("#{__MODULE__}[#{key}] joining :fact_indexers group")
    :ok = :pg.join(:fact_indexers, self())

    # Inform the manager this indexer is ready to rock
    send(Fact.EventDataIndexerManager, {:indexer_ready, self(), key})

    {:noreply, state}
  end

  def handle_info({:index, event}, state) do
    append_to_index(state, event)
    save_checkpoint(state, event)
    {:noreply, state}
  end

  defp append_to_index(%{key: key}, %{"data" => data, "id" => id}) do

    index_dir = Paths.index({:event_data, key})
    if Map.has_key?(data, key) do
      value = Map.get(data, key) |> hash_value

      file = Path.join(index_dir, value)
      File.write!(file, id <> "\n", [:append])
      :ok

    else
      :ignored
    end

  end

  defp hash_value(value) do
    binary = :erlang.term_to_binary(value)
    hash = :crypto.hash(:sha, binary)
    Base.encode16(hash, case: :lower)
  end

  defp load_checkpoint(%{checkpoint_file: file}) do
    case File.read(file) do
      {:ok, contents} -> contents |> String.trim() |> String.to_integer
      {:error, _} -> 0
    end
  end

  defp save_checkpoint(%{checkpoint_file: file}, %{"pos" => pos}) do
    File.write!(file, Integer.to_string(pos))
  end

end
