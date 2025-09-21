defmodule Fact.EventLedger do
  @moduledoc false

  use GenServer
  use Fact.EventKeys

  require Logger

  @registry_key {:via, Registry, {Fact.EventLedgerRegistry, :ledger}}

  defstruct [:last_pos]

  def start_link(opts) do
    state = %{last_pos: 0}
    start_opts = Keyword.put(opts, :name, @registry_key)
    GenServer.start_link(__MODULE__, state, start_opts)
  end

  def commit(events, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 5000)
    GenServer.call(@registry_key, {:commit, events, opts}, timeout)
  end

  def stream!(opts) do
    path = Application.get_env(:fact, :ledger)
    direction = Keyword.get(opts, :direction, :forward)
    case direction do
      :forward -> Fact.IndexFileReader.read_forward(path)
      :backward -> Fact.IndexFileReader.read_backward(path)
      other -> raise ArgumentError, "unknown direction #{inspect(other)}"
    end
  end

  # Server callbacks

  @impl true
  def init(state) do
    path = Application.get_env(:fact, :ledger)
    ensure_path!(path)
    last_pos = load_position(path)
    {:ok, %{state | last_pos: last_pos}}
  end

  @impl true
  def handle_call({:commit, events, opts}, _from, %{last_pos: last_pos} = state) do
    case Keyword.get(opts, :condition) do
      nil ->
        # no condition, stream append
        do_commit(events, state)

      {_event_query, expected_pos} when expected_pos == last_pos ->
        # nothing new, safe 
        do_commit(events, state)

      {event_query, expected_pos} when expected_pos < last_pos ->
        # run the query and check for any events 
        Fact.EventStreamReader.read(event_query, from_position: expected_pos)
        |> Stream.take(-1)
        |> Enum.at(0)
        |> case do
          nil ->
            do_commit(events, state)

          event ->
            {:reply,
             {:error,
              {:concurrency, expected: expected_pos, actual: event[@event_store_position]}}, state}
        end
    end
  end

  defp do_commit(events, %{last_pos: last_pos} = state) do
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
        case File.write(Application.get_env(:fact, :ledger), ledger_entry_iodata, [:append]) do
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
