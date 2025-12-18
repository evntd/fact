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
    * `:instance` - a `Fact.Instance` representing the database
    * `:mode` - the lock mode: `:run`, `:restore`, or `:create`
    * Other `GenServer` options.

  """
  def start_link(opts) do
    {lock_opts, genserver_opts} = Keyword.split(opts, [:instance, :mode])
    instance = Keyword.fetch!(lock_opts, :instance)
    mode = Keyword.fetch!(lock_opts, :mode)
    GenServer.start_link(__MODULE__, {instance, mode}, genserver_opts)
  end

  @impl true
  def init({instance, mode}) do
    case Fact.Lock.acquire(instance, mode) do
      {:ok, lock} ->
        {:ok, lock}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def terminate(_reason, lock) do
    Fact.Lock.release(lock)
    :ok
  end
end
