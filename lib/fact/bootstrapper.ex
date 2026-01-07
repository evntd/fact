defmodule Fact.Bootstrapper do
  @moduledoc """
  Boots a Fact database from disk.

  The bootstrapper read the **genesis event** (see `Fact.Genesis.Event.DatabaseCreated.V1`) from 
  the specified path, builds a `Fact.Context`, and starts the database under a `Fact.DatabaseSupervisor`.

  On success, the database is started and the bootstrapping process stops normally.
  If a `caller` PID is provided in the options, it will receive:

    * `{:database_started, database_id}`

  This process is temporary and is intended to run during startup.
  """
  use GenServer

  require Logger

  @type option ::
          {:path, Path.t()}
          | {:caller, pid()}

  @type options :: list(option)

  cond do
    Code.ensure_loaded?(Elixir.JSON) ->
      @decode_json &JSON.decode/1

    Code.ensure_loaded?(Jason) ->
      @decode_json &Jason.decode/1

    true ->
      @decode_json fn _ -> {:error, :no_json_library_available} end
  end

  @spec child_spec(options()) :: Supervisor.child_spec()
  def child_spec(opts) do
    path = Keyword.fetch!(opts, :path)

    %{
      id: {__MODULE__, path},
      start: {__MODULE__, :start_link, [opts]},
      restart: :temporary
    }
  end

  @spec start_link(options()) :: GenServer.on_start()
  def start_link(opts) do
    with {:ok, path} <- Keyword.fetch(opts, :path) do
      arg = %{
        path: path,
        caller: Keyword.get(opts, :caller)
      }

      GenServer.start_link(__MODULE__, arg, opts)
    else
      :error ->
        {:error, :missing_path}
    end
  end

  @impl true
  @doc false
  def init(args) do
    {:ok, args, {:continue, :bootstrap}}
  end

  @impl true
  @doc false
  def handle_continue(:bootstrap, %{path: path, caller: caller} = state) do
    with {:ok, context} <- load_context(path) do
      case Fact.Registry.get_context(context.database_id) do
        {:ok, _} ->
          maybe_send(caller, {:database_started, context.database_id})
          {:stop, :normal, state}

        {:error, _} ->
          case start_database(context) do
            {:ok, _pid} ->
              maybe_send(caller, {:database_started, context.database_id})
              {:stop, :normal, state}

            {:error, {:locked, lock_info}} ->
              maybe_send(caller, {:database_locked, lock_info})
              {:stop, :normal, state}

            {:error, reason} ->
              {:stop, reason, state}
          end
      end
    else
      {:error, reason} ->
        maybe_send(caller, {:database_error, reason})
        {:stop, :normal, state}
    end
  end

  defp start_database(context) do
    case Fact.Lock.status(context) do
      {:ok, :unlocked} ->
        Supervisor.start_child(Fact.Supervisor, {Fact.DatabaseSupervisor, [context: context]})

      {:ok, lock_info} ->
        {:error, {:locked, lock_info}}
    end
  end

  defp load_context(path) do
    ledger_file = Path.join(path, ".ledger")

    if File.exists?(ledger_file) do
      genesis_id =
        File.stream!(ledger_file)
        |> Enum.take(1)
        |> List.first()
        |> String.trim()

      genesis_path = Path.join([path, "events", genesis_id])
      {:ok, genesis_json} = File.read(genesis_path)
      {:ok, genesis_record} = @decode_json.(genesis_json)
      {:ok, Fact.Context.from_record(genesis_record)}
    else
      {:error, :database_not_found}
    end
  end

  defp maybe_send(caller, message) do
    if is_pid(caller), do: send(caller, message)
  end
end
