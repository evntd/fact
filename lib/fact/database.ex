defmodule Fact.Database do
  use GenServer
  
  @type t :: %__MODULE__{
               context: Fact.Context.t()
             }
  
  defstruct [:context, :lock]
  
  def start_link(opts) do
    {db_opts, gs_opts} = Keyword.split(opts, [:context])
    case Keyword.get(db_opts, :context) do
      nil ->
        {:error, :database_context_required}
      context ->
        GenServer.start_link(__MODULE__, context, gs_opts)    
    end
  end
  
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
end
