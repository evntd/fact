defmodule Fact.EventDataIndexer do
  use GenServer
  use Fact.EventKeys
  alias Fact.Paths
  require Logger

  def start_link(opts) do
    key = Keyword.fetch!(opts, :key)

    state = {:event_data, key}

    opts = Keyword.put_new(opts, :name, via_tuple(key))

    GenServer.start_link(__MODULE__, state, opts)
  end

  defp via_tuple(key), do: {:via, Registry, {Fact.EventDataIndexerRegistry, key}}

  def init(state) do
    ensure_paths!(state)
    {:ok, state, {:continue, :rebuild_and_join}}
  end

  def handle_continue(:rebuild_and_join, {_, key} = state) do
    checkpoint = load_checkpoint(state)
    Logger.debug("#{__MODULE__}[#{inspect(state)}] building index from #{@event_store_position} #{checkpoint}")
    
    Fact.EventReader.read_all(from_position: checkpoint)
    |> Stream.each(fn event ->
      append_to_index(event, state)
      save_checkpoint(event[@event_store_position], state)
    end)
    |> Stream.run()
    
    Logger.debug("#{__MODULE__}[#{key}] joining :fact_indexers group")
    :ok = :pg.join(:fact_indexers, self())

    # Inform the manager this indexer is ready to rock
    send(Fact.EventDataIndexerManager, {:indexer_ready, self(), key})

    {:noreply, state}
  end

  def handle_info({:index, event}, state) do
    append_to_index(event, state)
    save_checkpoint(event[@event_store_position], state)
    {:noreply, state}
  end
  
  defp index_event(%{@event_data => data} = _event, {_, key}) do
    case Map.has_key?(data, key) do
      true -> Map.get(data, key)
      false -> nil
    end
  end
  
  defp append_to_index(%{@event_id => id} = event, state) do
    case index_event(event, state) do
      nil -> :ignored
      value ->
        file = Path.join(Paths.index(state), hash_value(value))
        File.write!(file, id <> "\n", [:append])
        :ok
    end
  end

  defp hash_value(value) do
    binary = :erlang.term_to_binary(value)
    hash = :crypto.hash(:sha, binary)
    Base.encode16(hash, case: :lower)
  end

  defp load_checkpoint(state) do
    checkpoint_path = Paths.index_checkpoint(state)
    case File.read(checkpoint_path) do
      {:ok, contents} -> contents |> String.trim() |> String.to_integer
      {:error, _} -> 0
    end
  end

  defp save_checkpoint(position, state) do
    Paths.index_checkpoint(state)
    |> File.write!(Integer.to_string(position))
  end

  defp ensure_paths!(state) do
    File.mkdir_p!(Paths.index(state))
    checkpoint_path = Paths.index_checkpoint(state)
    unless File.exists?(checkpoint_path), do: File.write!(checkpoint_path, "0")
  end
end
