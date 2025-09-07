defmodule Fact.EventStreamIndexer do
  use GenServer
  require Logger
  defstruct [:index_dir, :checkpoint_file]

  def start_link(opts) do
    {start_opts, index_opts} = Keyword.split(opts, [:debug, :name, :timeout, :spawn_opt, :hibernate_after])

    index_dir = Keyword.fetch!(index_opts, :index_dir)

    state = %__MODULE__{
      index_dir: index_dir,
      checkpoint_file: Path.join(index_dir, ".checkpoint")
    }

    start_opts = Keyword.put_new(start_opts, :name, __MODULE__)

    GenServer.start_link(__MODULE__, state, start_opts)
  end

  def init(state) do
    Logger.debug("#{__MODULE__} init called")
    {:ok, state, {:continue, :rebuild_and_join} }
  end

  def handle_continue(:rebuild_and_join, state) do
    last_pos = load_checkpoint(state)


    Logger.debug("#{__MODULE__} rebuilding from #{last_pos}")

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

  defp append_to_index(%{index_dir: index_dir}, %{"stream" => stream, "id" => id}) do
    file = Path.join(index_dir, stream)
    File.write!(file, id <> "\n", [:append])
    :ok
  end

  defp append_to_index(_state, _event), do: :ignored

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
