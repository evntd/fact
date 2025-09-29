defmodule Fact.EventLedger do
  @moduledoc false

  use GenServer
  use Fact.EventKeys
  import Fact.Names
  require Logger

  defstruct [:instance, :path, last_pos: 0]

  def start_link(opts) do
    Logger.debug("#{__MODULE__}.start_link(#{inspect(opts)})")
    {ledger_opts, genserver_opts} = Keyword.split(opts, [:instance, :path])

    instance = Keyword.fetch!(ledger_opts, :instance)
    path = Keyword.fetch!(ledger_opts, :path)
    state = %__MODULE__{instance: instance, path: path}

    genserver_opts = Keyword.put(genserver_opts, :name, via(instance, __MODULE__))

    Logger.debug(
      "GenServer.start_link(#{__MODULE__}, #{inspect(state)}, #{inspect(genserver_opts)})"
    )

    GenServer.start_link(__MODULE__, state, genserver_opts)
  end

  def commit(instance, events, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 5000)
    GenServer.call(via(instance, __MODULE__), {:commit, events, opts}, timeout)
  end

  def stream!(instance, opts) do
    table = :"#{instance}.#{__MODULE__}"
    [{:path, path}] = :ets.lookup(table, :path)
    direction = Keyword.get(opts, :direction, :forward)

    case direction do
      :forward -> Fact.EventStorage.read_index_forward(instance, path)
      :backward -> Fact.EventStorage.read_index_backward(instance, path)
      other -> raise ArgumentError, "unknown direction #{inspect(other)}"
    end
  end

  # Server callbacks

  @impl true
  def init(%{instance: instance, path: path} = state) do
    table = :"#{instance}.#{__MODULE__}"
    :ets.new(table, [:named_table, :public, :set])
    :ets.insert(table, {:path, path})

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

  defp do_commit(events, %{instance: instance, last_pos: last_pos} = state) do
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

    case write_events(enriched_events, state) do
      {:ok, committed_events} ->
        Fact.EventPublisher.publish(instance, committed_events)
        {:reply, {:ok, end_pos}, %{state | last_pos: end_pos}}

      error ->
        {:reply, error, state}
    end
  end

  defp write_events(events, %{instance: instance, path: path} = _state) do
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
      |> Task.async_stream(&Fact.EventStorage.write_event(instance, &1),
        max_concurrency: System.schedulers_online()
      )
      |> Enum.reduce({:ok, [], [], []}, fn
        {_, {:ok, event_id}}, {result, iodata, written_events, errors} ->
          {result, [iodata, event_id, "\n"], [event_id | written_events], errors}

        {_, {:error, posix, event_id}}, {_, iodata, written_events, errors} ->
          {:error, iodata, written_events, [{posix, event_id} | errors]}
      end)

    case write_results do
      {:ok, ledger_entry_iodata, written_events, _errors} ->
        case File.write(path, ledger_entry_iodata, [:append]) do
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
