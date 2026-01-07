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
    context = load_context(path)

    with {:ok, _pid} <-
           Supervisor.start_child(Fact.Supervisor, {Fact.DatabaseSupervisor, [context: context]}) do
      if is_pid(caller) do
        send(caller, {:database_started, context.database_id})
      end

      {:stop, :normal, state}
    else
      {:error, reason} ->
        {:stop, reason, state}
    end
  end

  defp load_context(path) do
    genesis_id =
      File.stream!(Path.join(path, ".ledger"))
      |> Enum.take(1)
      |> List.first()
      |> String.trim()

    genesis_path = Path.join([path, "events", genesis_id])
    {:ok, genesis_json} = File.read(genesis_path)

    {:ok, genesis_record} =
      cond do
        Code.ensure_loaded?(Elixir.JSON) ->
          Elixir.JSON.decode(genesis_json)

        Code.ensure_loaded?(Jason) ->
          Jason.decode(genesis_json)
      end

    Fact.Context.from_record(genesis_record)
  end
end
