defmodule Fact.EventLedger do
  use GenServer
  use Fact.Types

  alias Fact.EventId
  alias Fact.RecordFile.Schema

  require Logger

  @type t :: %__MODULE__{
          database_id: Types.database_id(),
          position: non_neg_integer()
        }

  @type commit_opts :: [condition: query_condition] | [] | nil

  @type commit_success :: {:ok, Fact.Types.event_position()}

  @type query_condition ::
          Fact.EventQuery.t()
          | [Fact.EventQuery.t()]
          | {Fact.EventQuery.t(), Fact.Types.event_position()}
          | {[Fact.EventQuery.t()], Fact.Types.event_position()}

  @type write_events_error ::
          {:error, {:event_write_failed, [{File.posix(), Fact.Types.record_id()}]}}

  @type write_ledger_error ::
          {:error, {:ledger_write_failed, File.posix()}}

  @replacements %{
    data: @event_data,
    id: @event_id,
    metadata: @event_metadata,
    tags: @event_tags,
    type: @event_type
  }

  defstruct [:database_id, position: 0]

  @spec start_link([database_id: Fact.Types.database_id()] | []) ::
          {:ok, pid()} | {:error, term()}
  def start_link(opts) do
    {ledger_opts, genserver_opts} = Keyword.split(opts, [:database_id])
    database_id = Keyword.fetch!(ledger_opts, :database_id)
    GenServer.start_link(__MODULE__, database_id, genserver_opts)
  end

  @spec commit(
          Fact.Types.database_id(),
          Fact.Types.event() | [Fact.Types.event(), ...],
          Fact.Query.t(),
          Fact.Types.event_position(),
          keyword()
        ) :: {:ok, Fact.Types.event_position()} | {:error, term()}
  def commit(database_id, events, fail_if_match \\ nil, after_position \\ 0, opts \\ [])

  def commit(database_id, events, nil, after_position, opts),
    do: commit(database_id, events, Fact.Query.from_none(), after_position, opts)

  # TODO: Rework signatures to handle conversion of Fact.QueryItem to Fact.Query  

  def commit(database_id, event, fail_if_match, after_position, opts)
      when is_map(event) and not is_list(event) do
    commit(database_id, [event], fail_if_match, after_position, opts)
  end

  def commit(database_id, events, fail_if_match, after_position, opts) do
    cond do
      not is_list(events) ->
        {:error, :invalid_event_list}

      not Enum.all?(events, &is_map/1) ->
        {:error, :invalid_events}

      not Enum.all?(events, &is_map_key(&1, :type)) ->
        {:error, :missing_event_type}

      not is_function(fail_if_match, 1) ->
        {:error, :invalid_fail_if_match_query}

      not (is_integer(after_position) and after_position >= 0) ->
        {:error, :invalid_after_position}

      true ->
        timeout = Keyword.get(opts, :timeout, 5000)

        GenServer.call(
          Fact.Context.via(database_id, __MODULE__),
          {:commit, events, condition: {fail_if_match, after_position}},
          timeout
        )
    end
  end

  @impl true
  def init(database_id) do
    state = %{
      database_id: database_id,
      position: Fact.Database.last_position(database_id)
    }

    {:ok, state}
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

  defp conditional_commit(events, {_query, expected_pos}, %{position: position} = state)
       when expected_pos > position do
    Logger.warning(
      "expected position (#{expected_pos}) is greater than actual position (#{position})"
    )

    do_commit(events, state)
  end

  defp conditional_commit(
         events,
         {_condition, expected_pos} = condition,
         %{context: context, position: position} = state
       )
       when expected_pos < position do
    with :ok <- check_query_condition(context, condition) do
      do_commit(events, state)
    end
  end

  defp check_query_condition(context, {query, expected_pos}) do
    Fact.read(context, {:query, query}, position: expected_pos, return_type: :record)
    |> Stream.take(-1)
    |> Enum.at(0)
    |> case do
      nil ->
        :ok

      {_, record} ->
        {:error,
         Fact.ConcurrencyError.exception(
           source: :all,
           expected: expected_pos,
           actual: record[@event_store_position]
         )}
    end
  end

  defp do_commit(events, %{database_id: database_id, position: position} = state) do
    with {enriched_events, end_pos} <- enrich_events(database_id, {events, position}),
         {:ok, committed} <- commit_events(enriched_events, state) do
      Fact.EventPublisher.publish_appended(database_id, committed)

      {:ok, end_pos}
    end
  end

  defp enrich_events(database_id, {events, pos}) do
    with {:ok, context} <- Fact.Supervisor.get_context(database_id) do
      timestamp = DateTime.utc_now() |> DateTime.to_unix(:microsecond)

      Enum.map_reduce(events, pos, fn event, pos ->
        next = pos + 1

        event_with_renamed_keys =
          rename_keys(event, @replacements)

        enriched_event =
          %{}
          |> then(&Schema.set_event_data(context, &1, %{}))
          |> then(&Schema.set_event_id(context, &1, EventId.generate(context)))
          |> then(&Schema.set_event_metadata(context, &1, %{}))
          |> then(&Schema.set_event_tags(context, &1, []))
          |> then(&Schema.set_event_store_position(context, &1, next))
          |> then(&Schema.set_event_store_timestamp(context, &1, timestamp))
          |> Map.merge(event_with_renamed_keys)

        {enriched_event, next}
      end)
    end
  end

  defp commit_events(events, %{database_id: database_id} = _state) do
    with {:ok, context} <- Fact.Supervisor.get_context(database_id),
         {:ok, written_records} <- Fact.RecordFile.write(context, events) do
      Fact.LedgerFile.write(context, written_records)
    end
  end

  defp rename_keys(map, replacements) do
    Map.new(map, fn {key, value} ->
      new_key = Map.get(replacements, key, key)
      {new_key, value}
    end)
  end
end
