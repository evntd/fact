defmodule Fact.LockOwner do
  @moduledoc """
  A GenServer wrapper around `Fact.Lock` that manages the lifecycle of the exclusive lock.
    
  This module expects to be started under a supervisor, so that the lock will be automatically acquired when the
  process starts and automatically released when the process terminates, the VM shuts down or crashes.
  """
  use GenServer

  @doc """
  Starts the LockOwner server and acquires a lock for the given instance.

  ## Options
    * `:context` - a `Fact.Context` representing the database
    * `:mode` - the lock mode: `:run`, `:restore`, or `:create`
    * Other `GenServer` options.

  """
  def start_link(opts) do
    {lock_opts, genserver_opts} = Keyword.split(opts, [:context, :mode])
    context = Keyword.fetch!(lock_opts, :context)
    mode = Keyword.fetch!(lock_opts, :mode)
    GenServer.start_link(__MODULE__, {context, mode}, genserver_opts)
  end

  @impl true
  def init({context, mode}) do
    case Fact.Lock.acquire(context, mode) do
      {:ok, lock} ->
        {:ok, %{context: context, lock: lock}}

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
