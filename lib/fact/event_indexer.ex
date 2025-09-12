defmodule Fact.EventIndexer do
  @moduledoc """
  Base module for all indexers.
  """
  @callback index(any()) :: String.t() | nil
  
  defmacro __using__(name) do
    
    quote do
      @behaviour Fact.EventIndexer
      
      use GenServer
      use Fact.EventKeys
      alias Fact.Paths
      require Logger
      
      @index unquote(name)
      
      def start_link(opts \\ []) do
        name = Keyword.get(opts, :name, __MODULE__)
        GenServer.start_link(__MODULE__, opts, name: name)
      end
      
      @impl true
      def init(opts) do
        ensure_paths!()
        {:ok, %{}, {:continue, :rebuild_and_join}}
      end
      
      @impl true
      def handle_continue(:rebuild_and_join, state) do
        checkpoint = load_checkpoint()
        Logger.debug("#{__MODULE__} building index from #{@event_store_position} #{checkpoint}")
        
        Fact.EventReader.read_all(from_position: checkpoint)
        |> Stream.each(fn event ->
          append_to_index(event)
          save_checkpoint(event[@event_store_position])
        end)
        |> Stream.run()
        
        Logger.debug("#{__MODULE__} joining :fact_indexers group")
        :ok = :pg.join(:fact_indexers, self())
        {:noreply, state}
      end
      
      @impl true
      def handle_info({:index, event}, state) do
        append_to_index(event)
        save_checkpoint(event[@event_store_position])
        {:noreply, state}
      end

      defp append_to_index(%{@event_id => id} = event) do
        case index(event) do
          nil -> :ignored
          key ->
            file = Path.join(Paths.index(@index), key)
            File.write!(file, id <> "\n", [:append])
            :ok    
        end
      end
      
      defp load_checkpoint() do
        checkpoint_path = Paths.index_checkpoint(@index)
        case File.read(checkpoint_path) do
          {:ok, contents} -> contents |> String.trim() |> String.to_integer
          {:error, _} -> 0
        end
      end

      defp save_checkpoint(pos) do
        Paths.index_checkpoint(@index) 
        |> File.write!(Integer.to_string(pos))
      end
      
      defp ensure_paths!() do
        File.mkdir_p!(Paths.index(@index))
        checkpoint_path = Paths.index_checkpoint(@index)
        unless File.exists?(checkpoint_path), do: File.write!(checkpoint_path, "0")
      end
    end
  end
end