defmodule Fact.Bootstrapper do
  use GenServer

  require Logger

  def child_spec(opts) do
    path = Keyword.fetch!(opts, :path)

    %{
      id: {__MODULE__, path},
      start: {__MODULE__, :start_link, [opts]},
      restart: :temporary
    }
  end

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
  def init(args) do
    {:ok, args, {:continue, :bootstrap}}
  end

  @impl true
  def handle_continue(:bootstrap, %{path: path, caller: caller} = state) do
    context = load_context(path)

    with {:ok, _pid} <- Fact.Supervisor.start_database(context) do
      if is_pid(caller) do
        send(caller, {:database_started, context})
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
