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
      :forward -> Fact.Storage.read_index_forward(path)
      :backward -> Fact.Storage.read_index_backward(path)
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
        Fact.EventReader.read(event_query, from_position: expected_pos)
        |> Stream.take(-1)
        |> Enum.at(0)
        |> case do
          nil ->
            do_commit(events, state)

          event ->
            {:reply,
             {:error,
              {:concurrency, expected: expected_pos, actual: event[@event_store_position]}},
             state}
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
            # TODO: only if not specified
            @event_id => UUID.uuid4(:hex),
            @event_store_position => next_pos,
            @event_store_timestamp => timestamp
          })

        {enriched_event, next_pos}
      end)

    case write_events(enriched_events) do
      {:ok, committed_events} ->
        Fact.EventIndexerManager.index(committed_events)
        {:reply, {:ok, end_pos}, %{state | last_pos: end_pos}}

      error ->
        {:reply, error, state}
    end
  end

  defp write_events(events) do
    # write all the events, then collect the 
    #   - iodata, for writing all event_ids into the ledger
    #
    # on success
    #   - iodata for writing all event_ids into the ledger at once
    #   - the event_ids in a list for response to the caller
    #
    # on failure
    #   - the write failures, containing the error and event_id

    write_results =
      events
      |> Task.async_stream(&Fact.Storage.write_event/1, max_concurrency: System.schedulers_online())
      |> Enum.reduce({:ok, [], [], []}, fn
        {_, {:ok, event_id}}, {result, iodata, written_events, errors} ->
          {result, [iodata, event_id, "\n"], [event_id | written_events], errors}

        {_, {:error, posix, event_id}}, {_, iodata, written_events, errors} ->
          {:error, iodata, written_events, [{posix, event_id} | errors]}
      end)

    case write_results do
      {:ok, ledger_entry_iodata, written_events, _errors} ->
        case File.write(Application.get_env(:fact, :ledger), ledger_entry_iodata, [:append]) do
          :ok ->
            {:ok, written_events |> Enum.reverse()}

          {:error, reason} ->
            {:error, {:ledger_write_failed, reason}}
        end

      {:error, _ledger_entry_iodata, _written_events, errors} ->
        {:error, {:event_write_failed, Enum.reverse(errors)}}
    end
  end

  defp ensure_path!(path) do
    File.mkdir_p!(Path.dirname(path))
    unless File.exists?(path), do: File.write!(path, "")
  end

  defp load_position(path), do: File.stream!(path) |> Enum.count()
end
