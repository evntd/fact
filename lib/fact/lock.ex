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

  @type mode :: :run | :restore | :create
  @type lock_metadata :: map()

  @type t :: %__MODULE__{
          mode: mode(),
          socket: port(),
          socket_path: Path.t(),
          metadata_path: Path.t()
        }

  defstruct [:mode, :socket, :socket_path, :metadata_path]

  @modes [:run, :restore, :create]

  @spec acquire(Fact.Instance.t(), mode()) ::
          {:ok, t()} | {:error, {:locked, lock_metadata()}} | {:error, term()}
  @doc """
  Acquire a lock for the instance in the specified mode.
  """
  def acquire(%Fact.Instance{} = instance, mode) when mode in @modes do
    socket_path = Fact.Instance.lock_path(instance)
    metadata_path = Fact.Instance.lock_metadata_path(instance)

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

        File.write!(metadata_path, Fact.Json.encode!(metadata))

        {:ok,
         %__MODULE__{
           mode: mode,
           socket: socket,
           socket_path: socket_path,
           metadata_path: metadata_path
         }}

      {:error, :eaddrinuse} ->
        {:error, {:locked, read_metadata(metadata_path)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Gets the metadata of a lock.
  """
  @spec info(t() | Fact.Instance.t()) :: {:ok, lock_metadata()} | {:ok, :unlocked}
  def info(%Fact.Instance{} = instance) do
    info(
      Fact.Instance.lock_metadata_path(instance),
      Fact.Instance.lock_path(instance)
    )
  end

  def info(%__MODULE__{socket_path: socket_path, metadata_path: metadata_path}) do
    info(metadata_path, socket_path)
  end

  defp info(metadata_path, socket_path) do
    if File.exists?(metadata_path) and not stale_socket?(socket_path) do
      {:ok, File.read!(metadata_path) |> Fact.Json.decode!()}
    else
      {:ok, :unlocked}
    end
  end

  @doc """
  Release an acquired lock.
    
  Closes the socket, deletes the socket file, and deletes the metadata file.
  """
  @spec release(t()) :: :ok
  def release(%__MODULE__{socket: socket, socket_path: socket_path, metadata_path: metadata_path}) do
    :gen_tcp.close(socket)
    File.rm(socket_path)
    File.rm(metadata_path)
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

  defp read_metadata(path) do
    case File.read(path) do
      {:ok, contents} -> Fact.Json.decode!(contents)
      error -> error
    end
  end
end
