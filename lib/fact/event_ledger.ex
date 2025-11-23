defmodule Fact.EventLedger do
  use GenServer
  use Fact.EventKeys
  import Fact.Names
  require Logger

  @type t :: %__MODULE__{
          instance: :atom,
          position: non_neg_integer()
        }

  @type commit_opts :: [condition: query_condition] | [] | nil

  @type commit_success :: {:ok, Fact.Types.event_position()}

  @type concurrency_error ::
          {:error,
           {:concurrency,
            expected: Fact.Types.event_position(), actual: Fact.Types.event_position()}}

  @type query_condition ::
          Fact.EventQuery.t()
          | [Fact.EventQuery.t()]
          | {Fact.EventQuery.t(), Fact.Types.event_position()}
          | {[Fact.EventQuery.t()], Fact.Types.event_position()}

  @type write_events_error ::
          {:error, {:event_write_failed, [{File.posix(), Fact.Types.record_id()}]}}

  @type write_ledger_error ::
          {:error, {:ledger_write_failed, File.posix()}}

  defstruct [:instance, position: 0]

  @spec start_link([instance: atom()] | []) :: {:ok, pid()} | {:error, term()}
  def start_link(opts) do
    {ledger_opts, genserver_opts} = Keyword.split(opts, [:instance])
    instance = Keyword.fetch!(ledger_opts, :instance)
    genserver_opts = Keyword.put(genserver_opts, :name, via(instance, __MODULE__))
    GenServer.start_link(__MODULE__, instance, genserver_opts)
  end

  @spec commit(atom, [Fact.Types.event()], commit_opts()) ::
          commit_success | concurrency_error | write_events_error | write_ledger_error
  def commit(instance, events, commit_opts \\ []) do
    timeout = Keyword.get(commit_opts, :timeout, 5000)
    GenServer.call(via(instance, __MODULE__), {:commit, events, commit_opts}, timeout)
  end

  @impl true
  def init(instance) do
    :ok = Fact.Storage.ensure_ledger(instance)
    position = Fact.Storage.last_store_position(instance, :ledger)
    {:ok, %__MODULE__{instance: instance, position: position}}
  end

  @impl true
  def handle_call({:commit, events, commit_opts}, _from, state) do
    with {:ok, end_pos} <- conditional_commit(events, Keyword.get(commit_opts, :condition), state) do
      {:reply, {:ok, end_pos}, %{state | position: end_pos}}
    else
      error -> {:reply, error, state}
    end
  end

  defp conditional_commit(events, condition, state)
  defp conditional_commit(events, nil, state), do: do_commit(events, state)

  defp conditional_commit(events, {_query, expected_pos}, %{position: position} = state)
       when expected_pos == position,
       do: do_commit(events, state)

  defp conditional_commit(
         events,
         {_condition, expected_pos} = condition,
         %{position: position} = state
       )
       when expected_pos < position do
    with :ok <- check_query_condition(condition) do
      do_commit(events, state)
    end
  end

  defp check_query_condition({query, expected_pos}) do
    Fact.EventReader.read(query, from_position: expected_pos)
    |> Stream.take(-1)
    |> Enum.at(0)
    |> case do
      nil ->
        :ok

      event ->
        {:error, {:concurrency, expected: expected_pos, actual: event[@event_store_position]}}
    end
  end

  defp do_commit(events, %{instance: instance, position: position} = state) do
    with {enriched_events, end_pos} <- enrich_events({events, position}),
         {:ok, committed} <- commit_events(enriched_events, state) do
      Fact.EventPublisher.publish(instance, committed)
      {:ok, end_pos}
    end
  end

  defp enrich_events({events, pos}) do
    timestamp = DateTime.utc_now() |> DateTime.to_unix(:microsecond)

    Enum.map_reduce(events, pos, fn event, pos ->
      next = pos + 1

      enriched =
        Map.merge(event, %{
          @event_id => UUID.uuid4(:hex),
          @event_store_position => next,
          @event_store_timestamp => timestamp
        })

      {enriched, next}
    end)
  end

  defp commit_events(events, %{instance: instance} = _state) do
    with {:ok, written_records} <- write_events(events, instance) do
      write_ledger(instance, written_records)
    end
  end

  defp write_events(events, instance) do
    Task.async_stream(events, &Fact.Storage.write_event(instance, &1),
      max_concurrency: System.schedulers_online()
    )
    |> process_write_results()
  end

  defp write_ledger(instance, records) do
    case Fact.Storage.write_index(instance, :ledger, records) do
      :ok ->
        {:ok, records}

      {:error, reason} ->
        {:error, {:ledger_write_failed, reason}}
    end
  end

  defp process_write_results(write_results) do
    result =
      Enum.reduce(write_results, {:ok, [], []}, fn
        {_, {:ok, record_id}}, {result, records, errors} ->
          {result, [record_id | records], errors}

        {_, {:error, posix, record_id}}, {_, records, errors} ->
          {:error, records, [{posix, record_id} | errors]}
      end)

    case result do
      {:ok, records, []} ->
        {:ok, Enum.reverse(records)}

      {:error, _, errors} ->
        {:error, {:event_write_failed, Enum.reverse(errors)}}
    end
  end
end
