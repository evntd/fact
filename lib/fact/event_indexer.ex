defmodule Fact.EventIndexer do
  @moduledoc """
  Base module for all indexers.
  """
  @callback index_event(event :: map(), state :: term()) :: String.t() | nil
  
  defmacro __using__(_opts \\ []) do
    
    quote do
      @behaviour Fact.EventIndexer
      
      use GenServer
      use Fact.EventKeys
      require Logger
      
      defstruct [:index, :path, :encoding] 
      
      def start_link(opts \\ []) do

        {index_opts, start_opts} = Keyword.split(opts, [:key, :path, :encoding])
        
        index = 
          case Keyword.fetch(index_opts, :key) do
            {:ok, key} -> {__MODULE__, key}
            :error -> __MODULE__ 
          end

        base = Keyword.fetch!(index_opts, :path)
        encoding = Keyword.get(index_opts, :encoding, :raw)
          
        path =
          case index do
            {_mod, key} -> Path.join(base, to_string(key))
            _ -> base
          end 
        
        state = %__MODULE__{
          index: index,
          path: path,
          encoding: encoding
        }
        
        start_opts = Keyword.put_new(start_opts, :name, __MODULE__)
        GenServer.start_link(__MODULE__, state, start_opts)
      end
      
      @impl true
      def init(state) do
        ensure_paths!(state.path)
        {:ok, state, {:continue, :rebuild_and_join}}
      end
      
      @impl true
      def handle_continue(:rebuild_and_join, state) do
        checkpoint = load_checkpoint(state.path)
        Logger.debug("#{__MODULE__} building index from #{@event_store_position} #{checkpoint}")
        
        Fact.EventReader.read_all(from_position: checkpoint)
        |> Stream.each(fn event ->
          append_to_index(event, state)
          save_checkpoint(event[@event_store_position], state.path)
        end)
        |> Stream.run()
        
        Logger.debug("#{__MODULE__} joining :fact_indexers group")
        :ok = :pg.join(:fact_indexers, self())
        
        send(Fact.EventIndexerManager, {:indexer_ready, self(), state.index})
        
        {:noreply, state}
      end
      
      @impl true
      def handle_info({:index, event}, state) do
        append_to_index(event, state)
        save_checkpoint(event[@event_store_position], state.path)
        {:noreply, state}
      end
      
      @impl true
      def handle_cast({:stream, value, receiver}, %__MODULE__{index: index, path: path, encoding: encoding} = state) do
        file = Path.join(path, encode_key(value, encoding))
        
        event_ids =
          case File.exists?(file) do
            false ->
              {:error, {:index_not_found, index, value}}
            true ->
              File.stream!(file)
              |> Stream.map(&String.trim/1)
          end
        
        GenServer.reply(receiver, event_ids)
        
        {:noreply, state}
      end

      defp append_to_index(%{@event_id => id} = event, %__MODULE__{index: index, path: path, encoding: encoding}) do
        case index_event(event, index) do
          nil -> :ignored
          key ->
            file = Path.join(path, encode_key(key, encoding))
            File.write!(file, id <> "\n", [:append])
            :ok    
        end
      end
      
      defp load_checkpoint(path) do
        checkpoint_path = get_checkpoint_path(path)
        case File.read(checkpoint_path) do
          {:ok, contents} -> contents |> String.trim() |> String.to_integer
          {:error, _} -> 0
        end
      end

      defp save_checkpoint(position, path) do
        get_checkpoint_path(path) 
        |> File.write!(Integer.to_string(position))
      end
      
      defp ensure_paths!(path) do
        File.mkdir_p!(path)
        checkpoint_path = get_checkpoint_path(path)
        unless File.exists?(checkpoint_path), do: File.write!(checkpoint_path, "0")
      end
      
      defp get_checkpoint_path(path), do: Path.join(path, ".checkpoint")

      defp encode_key(value, encoding) do
        case encoding do
          :raw ->
            to_string(value)
          :hash ->
            :crypto.hash(:sha, to_string(value))
            |> Base.encode16(case: :lower)
          {:hash, algo} ->
            :crypto.hash(algo, to_string(value))
            |> Base.encode16(case: :lower)
          other ->
            raise ArgumentError, "unsupported encoding: #{inspect(other)}"
        end
      end
    end
  end
end