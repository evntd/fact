defmodule Fact.Indexer do
  @moduledoc """
  Base module for all indexers.
  """

  @callback index() :: atom 
  @callback index_event(any()) :: String.t() | nil
  
  defmacro __using__(_opts) do
    quote do
      use GenServer
      alias Fact.Paths
      require Logger
      
      @behaviour Fact.Indexer
      
      def start_link(opts \\ []) do
        name = Keyword.get(opts, :name, __MODULE__)
        GenServer.start_link(__MODULE__, opts, name: name)
      end
      
      @impl GenServer
      def init(opts) do
        index_name = index()
        state = %{
          index: index_name,
          checkpoint: Paths.index_checkpoint(index_name)
        }
        
        {:ok, state, {:continue, :rebuild_and_join}}
      end
      
      @impl GenServer
      def handle_continue(:rebuild_and_join, state) do
        checkpoint = load_checkpoint(state)
        Logger.debug("#{__MODULE__} building index from #{checkpoint}")
        
        Fact.EventReader.read_all(from_position: checkpoint)
        |> Stream.each(fn event ->
          append_to_index(state, event)
          save_checkpoint(state, event)
        end)
        |> Stream.run()
        
        Logger.debug("#{__MODULE__} joining :fact_indexers group")
        :ok = :pg.join(:fact_indexers, self())
        {:noreply, state}
      end
      
      def handle_info({:index, event}, state) do
        append_to_index(state, event)
        save_checkpoint(state, event)
        {:noreply, state}
      end

      defp append_to_index(%{index: index_name}, %{"id" => id} = event) do
        case index_event(event) do
          nil -> :ignored
          key ->
            file = Path.join(Paths.index(index_name), key)
            File.write!(file, id <> "\n", [:append])
            :ok    
        end
      end
      
      defp load_checkpoint(%{checkpoint: file}) do
        case File.read(file) do
          {:ok, contents} -> contents |> String.trim() |> String.to_integer
          {:error, _} -> 0
        end
      end

      defp save_checkpoint(%{checkpoint: file}, %{"pos" => pos}) do
        File.write!(file, Integer.to_string(pos))
      end

      defp wait_for_pg(attempt \\ 0) do
        case Process.whereis(:pg) do
          nil when attempt < 20 ->
            :timer.sleep(50)
            wait_for_pg(attempt + 1)
          nil ->
            raise ":pg never started after 1 second"
          _pid -> :ok
        end
      end
    end
  end
end