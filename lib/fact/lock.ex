defmodule Fact.Lock do
  @moduledoc """
  Provides a cross-VM exclusive lock for Fact database instances.
    
  This modules uses a UNIX Domain Socket to coordinate access to a Fact instance,
  ensuring that only one BEAM VM can perform certain operations at a time. The 
  lock defines three modes.
    
    * `:run` - normal instance operation
    * `:restore` - doing an overwrite restore of a backup
    * `:create` - initialization of a new instance

  ## Features
    
    * **Cross-VM safe:** Only one process across all BEAM VMs can hold the lock at a time.
    * **Crash-safe:** The lock is automatically released if the owning VM exits.
    * **Stale cleanup:** Detects and removes stale socket files left by crashed processes.
    * **Metadata:** Store JSON metadata including the OS PID, BEAM PID, BEAM node, lock mode, and timestamp.

  """

  alias Fact.Context
  alias Fact.LockFile
  alias Fact.Storage

  @type mode :: :run | :restore | :create
  @type lock_metadata :: map()

  @type t :: %__MODULE__{
          mode: mode(),
          socket: port(),
          socket_path: Path.t()
        }

  defstruct [:mode, :socket, :socket_path, :metadata_path]

  @modes [:run, :restore, :create]

  @spec acquire(Context.t(), mode()) ::
          {:ok, t()} | {:error, {:locked, lock_metadata()}} | {:error, term()}
  @doc """
  Acquire a lock for the instance in the specified mode.
  """
  def acquire(%Context{} = context, mode) when mode in @modes do
    socket_path = Path.join(Storage.locks_path(context), "lock.sock")
    if stale_socket?(socket_path), do: File.rm(socket_path)

    case :gen_tcp.listen(0, [:binary, active: false, ip: {:local, socket_path}]) do
      {:ok, socket} ->
        metadata = %{
          mode: mode,
          os_pid: System.pid(),
          vm_pid: Kernel.inspect(self()),
          node: node(),
          locked_at: DateTime.utc_now() |> DateTime.to_iso8601()
        }

        :ok = LockFile.write(context, metadata)

        {:ok,
         %__MODULE__{
           mode: mode,
           socket: socket,
           socket_path: socket_path
         }}

      {:error, :eaddrinuse} ->
        {:error, {:locked, LockFile.read(context)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Release an acquired lock.
    
  Closes the socket, deletes the socket file, and deletes the metadata file.
  """
  @spec release(Context.t(), t()) :: :ok
  def release(%Context{} = context, %__MODULE__{socket: socket, socket_path: socket_path}) do
    :gen_tcp.close(socket)
    File.rm(socket_path)
    LockFile.delete(context)
    :ok
  end

  defp stale_socket?(path) do
    if File.exists?(path) do
      case :gen_tcp.connect({:local, path}, 0, [:binary, active: false]) do
        {:ok, conn} ->
          :gen_tcp.close(conn)
          false

        {:error, _} ->
          true
      end
    else
      false
    end
  end
end
