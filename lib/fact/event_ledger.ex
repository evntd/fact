defmodule Fact.EventLedger do
  @moduledoc false

  use GenServer
  use Fact.EventKeys

  require Logger

  @registry_key {:via, Registry, {Fact.EventLedgerRegistry, :ledger}}

  defstruct [:path, :last_pos]

  def start_link(opts) do
    # TODO: Factor configuration out to the application.
    path = Application.get_env(:fact, :ledger)
    state = %{path: path, last_pos: 0}
    start_opts = Keyword.put(opts, :name, @registry_key)
    GenServer.start_link(__MODULE__, state, start_opts)
  end

  def commit(events) do
    GenServer.call(@registry_key, {:commit, events})
  end

  def last_position() do
    GenServer.call(@registry_key, :last_position)
  end

  def stream!(opts \\ []) do
    GenServer.call(@registry_key, {:stream!, opts})
  end

  # Server callbacks

  @impl true
  def init(%{path: path} = state) do
    ensure_path!(path)
    last_pos = load_position(path)
    {:ok, %{state | last_pos: last_pos}}
  end

  @impl true
  def handle_call(:last_position, _from, %{last_pos: last_pos} = state) do
    {:reply, last_pos, state}
  end

  @impl true
  def handle_call({:commit, events}, _from, %{last_pos: last_pos, path: path} = state) do
    timestamp = DateTime.utc_now() |> DateTime.to_unix(:microsecond)

    # Enrich with store metadata
    {enriched_events, end_pos} =
      Enum.map_reduce(events, last_pos, fn event, pos ->
        next_pos = pos + 1

        enriched_event =
          Map.merge(event, %{
            @event_id => UUID.uuid4(:hex),
            @event_store_position => next_pos,
            @event_store_timestamp => timestamp
          })

        {enriched_event, next_pos}
      end)

    case write_events(enriched_events) do
      {:ok, ledger_entry_iodata} ->
        case File.write(path, ledger_entry_iodata, [:append]) do
          :ok ->
            :ok =
              enriched_events
              |> Enum.map(& &1[@event_id])
              |> Fact.EventIndexerManager.index()

            {:reply, {:ok, end_pos}, %{state | last_pos: end_pos}}

          {:error, reason} ->
            {:reply, {:error, {:ledger_write_failed, reason}}, state}
        end

      {:error, reasons} ->
        {:reply, {:error, {:event_write_failed, reasons}}, state}
    end
  end

  def handle_call({:stream!, opts}, _from, %{path: path} = state) do
    direction = Keyword.get(opts, :direction, :forward)

    event_ids =
      case direction do
        :forward -> Fact.IndexFileReader.read_forward(path)
        :backward -> Fact.IndexFileReader.read_backward(path)
        other -> raise ArgumentError, "unknown direction #{inspect(other)}"
      end

    {:reply, event_ids, state}
  end

  defp write_events(events) do
    write_results =
      events
      |> Task.async_stream(
        fn event ->
          case Fact.EventWriter.write_event(event) do
            :ok -> {:ok, event[@event_id]}
            {:error, posix} -> {:error, posix, event[@event_id]}
          end
        end,
        max_concurrency: System.schedulers_online()
      )
      |> Enum.reduce({:ok, [], []}, fn
        {_, {:ok, event_id}}, {result, iodata, errors} ->
          {result, [iodata, event_id, "\n"], errors}

        {_, {:error, posix, event_id}}, {_, iodata, errors} ->
          {:error, iodata, [{posix, event_id} | errors]}
      end)

    case write_results do
      {:ok, ledger_entry_iodata, _errors} ->
        {:ok, ledger_entry_iodata}

      {:error, _ledger_entry_iodata, errors} ->
        {:error, Enum.reverse(errors)}
    end
  end

  defp ensure_path!(path) do
    File.mkdir_p!(Path.dirname(path))
    unless File.exists?(path), do: File.write!(path, "")
  end

  defp load_position(path), do: File.stream!(path) |> Enum.count()
end
