defmodule Fact.EventLedger do
  @moduledoc false

  use GenServer
  use Fact.EventKeys
  
  require Logger

  @registry_key {:via, Registry, {Fact.EventLedgerRegistry, :ledger}}

  # defstruct [:path, :last_pos]

  def start_link(opts) do
    # TODO: Factor configuration out to the application.
    ledger_opts = Application.get_env(:fact, :ledger)
    path = Keyword.fetch!(ledger_opts, :path)
    state = %{logfile: Path.join(path, ".log"), events_dir: path}
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
  def init(state) do
    ensure_paths!(state)
    last_pos = load_position(state.logfile)
    {:ok, Map.put(state, :last_pos, last_pos)}
  end

  @impl true
  def handle_call(:last_position, _from, %{last_pos: last_pos} = state) do
    {:reply, last_pos, state}
  end

  @impl true
  def handle_call({:commit, events}, _from, %{last_pos: last_pos} = state) do
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

    case write_events(state.events_dir, enriched_events) do
      {:ok, ledger_entry, event_paths} ->
        Logger.debug("writing to ledger: #{inspect(ledger_entry)}")
        case File.write(state.logfile, ledger_entry, [:append]) do
          :ok ->
            # TODO Fix this index message
            :ok = Fact.EventIndexerManager.index(event_paths)
            
            {:reply, {:ok, end_pos}, %{state | last_pos: end_pos}}

          {:error, reason} ->
            {:reply, {:error, {:ledger_write_failed, reason}}, state}
        end

      {:error, reasons} ->
        {:reply, {:error, {:event_write_failed, reasons}}, state}
    end
  end
  
  def handle_call({:stream!, opts}, _from, %{logfile: path} = state) do
    direction = Keyword.get(opts, :direction, :forward)

    event_ids = 
      case direction do
        :forward -> Fact.IndexFileReader.read_forward(path)
        :backward -> Fact.IndexFileReader.read_backward(path)
        other -> raise ArgumentError, "unknown direction #{inspect(other)}"
      end
      
    events = 
      event_ids 
      |> Stream.map(&Path.join(state.events_dir, &1))
      |> Stream.map(&Fact.EventReader.Json.read_event/1)
      
    {:reply, events, state}
  end
  
  defp write_events(path, events) do
    write_results =
      events
      |> Enum.map(fn event -> {event, Path.join(path, event[@event_id])} end)
      |> Task.async_stream(fn {event, event_path} -> 
          case Fact.EventWriter.write_event(event_path, event) do
            :ok -> {:ok, event, event_path}
            {:error, posix} -> {:error, posix, event, event_path}
          end
      end, max_concurrency: System.schedulers_online())
      |> Enum.reduce({:ok, [], [], []}, fn
        {_, {:ok, event, event_path }}, {result, iodata, event_paths, errors} ->
          {result, [iodata, event[@event_id], "\n"], [event_paths, event_path], errors}

        {_, {:error, posix, event, _event_path}}, {_, iodata, event_paths, errors} ->
          {:error, iodata, event_paths, [{posix, event} | errors]}
      end)

    case write_results do
      {:ok, ledger_entry_iodata, event_paths, _errors} ->
        {:ok, ledger_entry_iodata, event_paths}

      {:error, _ledger_entry_iodata, _event_paths, errors} ->
        {:error, Enum.reverse(errors)}
    end
  end

  defp ensure_paths!(state) do
    File.mkdir_p!(state.events_dir)
    File.mkdir_p!(Path.dirname(state.logfile))
    unless File.exists?(state.logfile), do: File.write!(state.logfile, "")
  end

  defp load_position(path), do: File.stream!(path) |> Enum.count()
end
