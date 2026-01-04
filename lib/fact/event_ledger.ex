defmodule Fact.EventLedger do
  use GenServer
  use Fact.Types

  alias Fact.EventId
  alias Fact.RecordFile.Schema

  require Logger

  @type t :: %__MODULE__{
          context: Fact.Context.t(),
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

  defstruct [:context, position: 0]

  @spec start_link([context: Fact.Context.t()] | []) :: {:ok, pid()} | {:error, term()}
  def start_link(opts) do
    {ledger_opts, genserver_opts} = Keyword.split(opts, [:context])
    context = Keyword.fetch!(ledger_opts, :context)
    GenServer.start_link(__MODULE__, context, genserver_opts)
  end

  @spec commit(
          Fact.Context.t(),
          Fact.Types.event() | [Fact.Types.event(), ...],
          Fact.Query.t(),
          Fact.Types.event_position(),
          keyword()
        ) :: {:ok, Fact.Types.event_position()} | {:error, term()}
  def commit(context, events, fail_if_match \\ nil, after_position \\ 0, opts \\ [])

  def commit(%Fact.Context{} = context, events, nil, after_position, opts),
    do: commit(context, events, Fact.Query.from_none(), after_position, opts)

  # TODO: Rework signatures to handle conversion of Fact.QueryItem to Fact.Query  

  def commit(%Fact.Context{} = context, event, fail_if_match, after_position, opts)
      when is_map(event) and not is_list(event) do
    commit(context, [event], fail_if_match, after_position, opts)
  end

  def commit(%Fact.Context{} = context, events, fail_if_match, after_position, opts) do
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
          Fact.Context.via(context, __MODULE__),
          {:commit, events, condition: {fail_if_match, after_position}},
          timeout
        )
    end
  end

  @impl true
  def init(%Fact.Context{} = context) do
    state = %{
      context: context,
      position: Fact.Context.last_store_position(context)
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

  defp do_commit(events, %{context: context, position: position} = state) do
    with {enriched_events, end_pos} <- enrich_events(context, {events, position}),
         {:ok, committed} <- commit_events(enriched_events, state) do
      Fact.EventPublisher.publish(context, committed)
      {:ok, end_pos}
    end
  end

  defp enrich_events(%Fact.Context{} = context, {events, pos}) do
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

  defp commit_events(events, %{context: context} = _state) do
    with {:ok, written_records} <- Fact.RecordFile.write(context, events) do
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
