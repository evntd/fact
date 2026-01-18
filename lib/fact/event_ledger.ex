defmodule Fact.EventLedger do
  @moduledoc """
  Manages the event ledger for a Fact database instance, handling all commits,
  enforcing optimistic concurrency control via position expectations or query conditions.

  `Fact.EventLedger` is a GenServer responsible for:
    * Writing event record files, and appending to the ledger.
    * Ensuring events are enriched with metadata, ids, timestamps, and store positions
    * Publishing appended events via `Fact.EventPublisher`
    * Tracking the current ledger position and maintaining order.

  It's the Judge Judy of the system.
  """

  use GenServer

  alias Fact.Event

  require Logger

  @type t :: %__MODULE__{
          database_id: Fact.database_id(),
          position: Fact.event_position(),
          schema: Fact.event_record_schema(),
          replacements: map()
        }

  @type write_events_error ::
          {:error, {:event_write_failed, [{File.posix(), Fact.record_id()}]}}

  @type write_ledger_error ::
          {:error, {:ledger_write_failed, File.posix()}}

  defstruct [:database_id, :schema, :replacements, position: 0]

  @spec start_link([database_id: Fact.database_id()] | []) ::
          {:ok, pid()} | {:error, term()}
  def start_link(opts) do
    {ledger_opts, genserver_opts} = Keyword.split(opts, [:database_id])
    database_id = Keyword.fetch!(ledger_opts, :database_id)
    GenServer.start_link(__MODULE__, database_id, genserver_opts)
  end

  @spec commit(
          Fact.database_id(),
          Fact.event() | [Fact.event()],
          Fact.append_condition(),
          keyword()
        ) :: {:ok, Fact.event_position()} | {:error, term()}
  def commit(database_id, events, append_condition \\ nil, options \\ [])

  def commit(database_id, events, nil, options)
      when is_binary(database_id) and is_list(options) do
    commit(database_id, List.wrap(events), nil, 0, options)
  end

  def commit(database_id, events, %Fact.QueryItem{} = append_condition, options)
      when is_binary(database_id) and is_list(options) do
    commit(
      database_id,
      List.wrap(events),
      Fact.QueryItem.to_function(append_condition),
      0,
      options
    )
  end

  def commit(database_id, events, [%Fact.QueryItem{} | _] = append_condition, options)
      when is_binary(database_id) and is_list(options) do
    commit(
      database_id,
      List.wrap(events),
      Fact.QueryItem.to_function(append_condition),
      0,
      options
    )
  end

  def commit(database_id, events, append_condition, options)
      when is_binary(database_id) and is_function(append_condition) and is_list(options) do
    commit(database_id, List.wrap(events), append_condition, 0, options)
  end

  def commit(database_id, events, {%Fact.QueryItem{} = fail_if_match, after_position}, options)
      when is_binary(database_id) and is_integer(after_position) and is_list(options) do
    commit(
      database_id,
      List.wrap(events),
      Fact.QueryItem.to_function(fail_if_match),
      after_position,
      options
    )
  end

  def commit(
        database_id,
        events,
        {[%Fact.QueryItem{} | _] = fail_if_match, after_position},
        options
      )
      when is_binary(database_id) and is_integer(after_position) and is_list(options) do
    commit(
      database_id,
      List.wrap(events),
      Fact.QueryItem.to_function(fail_if_match),
      after_position,
      options
    )
  end

  def commit(database_id, events, {fail_if_match, after_position}, options)
      when is_binary(database_id) and is_function(fail_if_match) and is_integer(after_position) and
             is_list(options) do
    commit(database_id, List.wrap(events), fail_if_match, after_position, options)
  end

  defp commit(database_id, events, fail_if_match, after_position, opts) do
    cond do
      not is_list(events) ->
        {:error, :invalid_event_list}

      not Enum.all?(events, &is_map/1) ->
        {:error, :invalid_events}

      not Enum.all?(events, &is_map_key(&1, :type)) ->
        {:error, :missing_event_type}

      not (is_integer(after_position) and after_position >= 0) ->
        {:error, :invalid_after_position}

      true ->
        timeout = Keyword.get(opts, :timeout, 5000)

        GenServer.call(
          Fact.Registry.via(database_id, __MODULE__),
          {:commit, events, condition: {fail_if_match, after_position}},
          timeout
        )
    end
  end

  @impl true
  def init(database_id) do
    schema = Event.Schema.get(database_id)

    replacements = %{
      data: schema.event_data,
      id: schema.event_id,
      metadata: schema.event_metadata,
      tags: schema.event_tags,
      type: schema.event_type
    }

    state = %__MODULE__{
      database_id: database_id,
      position: Fact.Database.last_position(database_id),
      schema: schema,
      replacements: replacements
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
         %{position: position} = state
       )
       when expected_pos < position do
    with :ok <- check_query_condition(state, condition) do
      do_commit(events, state)
    end
  end

  defp check_query_condition(%{} = _state, {nil, _pos}) do
    :ok
  end

  defp check_query_condition(
         %{database_id: database_id, schema: schema} = _state,
         {query, expected_pos}
       ) do
    Fact.Database.read_query(database_id, query, position: expected_pos, result: :record)
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
           actual: record[schema.event_store_position]
         )}
    end
  end

  defp do_commit(events, %{database_id: database_id} = state) do
    with {enriched_events, end_pos} <- enrich_events(events, state),
         {:ok, committed} <- commit_events(enriched_events, state) do
      Fact.EventPublisher.publish_appended(database_id, committed)

      {:ok, end_pos}
    end
  end

  defp enrich_events(events, %{
         database_id: database_id,
         schema: schema,
         replacements: replacements,
         position: pos
       }) do
    timestamp = DateTime.utc_now() |> DateTime.to_unix(:microsecond)

    Enum.map_reduce(events, pos, fn event, pos ->
      next = pos + 1

      event_with_renamed_keys =
        rename_keys(event, replacements)

      enriched_event =
        %{
          schema.event_data => %{},
          schema.event_id => Event.Id.generate(database_id),
          schema.event_metadata => %{},
          schema.event_tags => [],
          schema.event_store_position => next,
          schema.event_store_timestamp => timestamp
        }
        |> Map.merge(event_with_renamed_keys)

      {enriched_event, next}
    end)
  end

  defp commit_events(events, %{database_id: database_id} = _state) do
    with {:ok, written_records} <- Fact.RecordFile.write(database_id, events) do
      Fact.LedgerFile.write(database_id, written_records)
    end
  end

  defp rename_keys(map, replacements) do
    Map.new(map, fn {key, value} ->
      new_key = Map.get(replacements, key, key)
      {new_key, value}
    end)
  end
end
