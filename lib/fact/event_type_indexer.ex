defmodule Fact.EventTypeIndexer do
  use GenServer
  alias Fact.Paths
  require Logger
    
  defstruct [:index_dir, :checkpoint_file]

  def start_link(opts) do
    
    state = %__MODULE__{
      index_dir: Paths.index(:event_type),
      checkpoint_file: Paths.index_checkpoint(:event_type)
    }

    opts = Keyword.put_new(opts, :name, __MODULE__)

    GenServer.start_link(__MODULE__, state, opts)
  end

  def init(state) do
    Logger.debug("#{__MODULE__} init called")
    {:ok, state, {:continue, :rebuild_and_join} }
  end

  def handle_continue(:rebuild_and_join, state) do
    last_pos = load_checkpoint(state)

    Logger.debug("#{__MODULE__} building index from #{last_pos}")

    Fact.EventReader.read_all(from_position: last_pos)
    |> Enum.each(fn event ->
      append_to_index(state, event)
      save_checkpoint(state, event)
    end)

    Logger.debug("#{__MODULE__} joining :fact_indexers group")
    :ok = :pg.join(:fact_indexers, self())
    {:noreply, state}
  end

  def handle_info({:index, event}, state) do
    append_to_index(state, event)
    save_checkpoint(state, event)
    {:noreply, state}
  end

  defp append_to_index(%{index_dir: index_dir}, %{"type" => type, "id" => id}) do
    file = Path.join(index_dir, type)
    File.write!(file, id <> "\n", [:append])
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
