defmodule Fact.Database do
  use GenServer

  @type t :: %__MODULE__{
          context: Fact.Context.t()
        }

  defstruct [:context, :lock]

  #  def start_indexer(%Fact.Context{} = context, indexer_module, opts \\ []) do
  #    {call_opts, indexer_opts} = Keyword.split(opts, [:timeout])
  #    GenServer.call(Fact.Context.via(context, __MODULE__), {:start_indexer, indexer_module, indexer_opts}, call_opts)
  #  end

  def start_link(options) do
    {opts, start_opts} = Keyword.split(options, [:context])

    case Keyword.get(opts, :context) do
      nil ->
        {:error, :database_context_required}

      context ->
        GenServer.start_link(__MODULE__, context, start_opts)
    end
  end

  #  @impl true
  #  def handle_call({:decide, command}, _from, state) do
  #    {:reply, decide(state, command), state}
  #  end
  #  
  #  @impl true
  #  def handle_cast({:evolve, event}, state) do
  #    {:noreply, evolve(state, event)}        
  #  end

  @impl true
  def init(context) do
    case Fact.Lock.acquire(context, :run) do
      {:ok, lock} ->
        state = %__MODULE__{
          context: context,
          lock: lock
        }

        {:ok, state}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def terminate(_reason, %{context: context, lock: lock}) do
    Fact.Lock.release(context, lock)
    :ok
  end

  #  defp decide({:start_indexer, indexer_module, indexer_opts}, state) do
  #    
  #  end
  #  
  #  defp evolve({:indexer_started, data}, state) do
  #    
  #  end
end
