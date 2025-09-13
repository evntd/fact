defmodule Fact.EventIndexer do
  @moduledoc """
  Base module for all indexers.
  """
  @callback index(event :: map(), state :: term()) :: String.t() | nil
  
  defmacro __using__(kind) do
    
    quote do
      @behaviour Fact.EventIndexer
      
      use GenServer
      use Fact.EventKeys
      alias Fact.Paths
      require Logger
      
      @kind unquote(kind)
      
      def start_link(opts \\ []) do
        state = 
          case Keyword.fetch(opts, :key) do
            {:ok, key} -> {@kind, key}
            :error -> @kind 
          end
        
        opts = Keyword.put_new(opts, :name, __MODULE__)
        GenServer.start_link(__MODULE__, state, opts)
      end
      
      @impl true
      def init(state) do
        ensure_paths!(state)
        {:ok, state, {:continue, :rebuild_and_join}}
      end
      
      @impl true
      def handle_continue(:rebuild_and_join, state) do
        checkpoint = load_checkpoint(state)
        Logger.debug("#{__MODULE__} building index from #{@event_store_position} #{checkpoint}")
        
        Fact.EventReader.read_all(from_position: checkpoint)
        |> Stream.each(fn event ->
          append_to_index(event, state)
          save_checkpoint(event[@event_store_position], state)
        end)
        |> Stream.run()
        
        Logger.debug("#{__MODULE__} joining :fact_indexers group")
        :ok = :pg.join(:fact_indexers, self())
        {:noreply, state}
      end
      
      @impl true
      def handle_info({:index, event}, state) do
        append_to_index(event, state)
        save_checkpoint(event[@event_store_position], state)
        {:noreply, state}
      end

      defp append_to_index(%{@event_id => id} = event, state) do
        case index(event, state) do
          nil -> :ignored
          key ->
            file = Path.join(Paths.index(state), key)
            File.write!(file, id <> "\n", [:append])
            :ok    
        end
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
  end
end