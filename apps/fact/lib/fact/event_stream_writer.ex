defmodule Fact.EventStreamWriter do
  @moduledoc """
  A per-stream, on-demand GenServer responsible for serializing writes to an event stream. 
  It ensures that events are appended in order, enriched with stream metadata, and committed atomically.
  """
  use GenServer

  require Logger

  @idle_timeout :timer.minutes(1)

  defstruct [:database_id, :event_stream, :last_pos, :idle_timer, :schema]

  def child_spec(opts) do
    database_id = Keyword.fetch!(opts, :database_id)
    event_stream = Keyword.fetch!(opts, :event_stream)

    %{
      id: {__MODULE__, {database_id, event_stream}},
      start: {__MODULE__, :start_link, [opts]},
      restart: :temporary,
      shutdown: 5000,
      type: :worker
    }
  end

  def start_link(opts) do
    database_id = Keyword.fetch!(opts, :database_id)
    event_stream = Keyword.fetch!(opts, :event_stream)
    start_opts = Keyword.put(opts, :name, Fact.Registry.via(database_id, event_stream))

    GenServer.start_link(
      __MODULE__,
      [database_id: database_id, event_stream: event_stream],
      start_opts
    )
  end

  @spec commit(
          Fact.database_id(),
          Fact.event() | [Fact.event(), ...],
          Fact.event_stream_id(),
          Fact.event_position() | :any | :none | :exists,
          keyword()
        ) :: {:ok, Fact.event_position()} | {:error, term()}
  def commit(database_id, events, event_stream, expected_position \\ :any, opts \\ [])

  def commit(database_id, event, event_stream, expected_position, opts)
      when is_map(event) and not is_list(event) do
    commit(database_id, [event], event_stream, expected_position, opts)
  end

  def commit(database_id, events, event_stream, expected_position, opts) do
    cond do
      not is_list(events) ->
        {:error, :invalid_event_list}

      not Enum.all?(events, &is_map/1) ->
        {:error, :invalid_events}

      not Enum.all?(events, &is_map_key(&1, :type)) ->
        {:error, :missing_event_type}

      not is_binary(event_stream) ->
        {:error, :invalid_event_stream}

      not (:any == expected_position or :none == expected_position or :exists == expected_position or
               (is_integer(expected_position) and expected_position >= 0)) ->
        {:error, :invalid_expected_position}

      true ->
        ensure_started(database_id, event_stream)

        GenServer.call(
          Fact.Registry.via(database_id, event_stream),
          {:commit, events, expected_position},
          Keyword.get(opts, :timeout, 5000)
        )
    end
  end

  defp ensure_started(database_id, event_stream) do
    case Fact.Registry.lookup(database_id, event_stream) do
      [] ->
        DynamicSupervisor.start_child(
          Fact.Registry.via(database_id, Fact.EventStreamWriterSupervisor),
          {__MODULE__, [database_id: database_id, event_stream: event_stream]}
        )

      _ ->
        :ok
    end
  end

  # Server callbacks

  @impl true
  def init(opts) do
    database_id = Keyword.fetch!(opts, :database_id)
    event_stream = Keyword.fetch!(opts, :event_stream)

    state = %__MODULE__{
      database_id: database_id,
      event_stream: event_stream,
      last_pos: 0,
      idle_timer: schedule_idle_timeout(),
      schema: Fact.Event.Schema.get(database_id)
    }

    {:ok, state, {:continue, :load_position}}
  end

  @impl true
  def handle_continue(
        :load_position,
        %{database_id: database_id, event_stream: event_stream} = state
      ) do
    last_pos = Fact.EventStreamIndexer.last_stream_position(database_id, event_stream)
    {:noreply, %{state | last_pos: last_pos}}
  end

  @impl true
  def handle_call(
        {:commit, events, expect},
        _from,
        %{
          database_id: database_id,
          event_stream: event_stream,
          last_pos: last_pos,
          schema: schema
        } = state
      ) do
    cancel_idle_timeout(state.idle_timer)
    idle_timer = schedule_idle_timeout()

    if not consistent?(expect, last_pos) do
      {:reply,
       {:error,
        Fact.ConcurrencyError.exception(source: event_stream, expected: expect, actual: last_pos)},
       %{state | idle_timer: idle_timer}}
    else
      {enriched_events, end_pos} =
        Enum.map_reduce(events, last_pos, fn event, pos ->
          next_pos = pos + 1

          enriched_event =
            Map.merge(event, %{
              schema.event_stream_id => event_stream,
              schema.event_stream_position => next_pos
            })

          {enriched_event, next_pos}
        end)

      case Fact.EventLedger.commit(database_id, enriched_events) do
        {:ok, _last_store_pos} ->
          {:reply, {:ok, end_pos}, %{state | idle_timer: idle_timer, last_pos: end_pos}}

        {:error, reason} ->
          {:reply, {:error, reason}, %{state | idle_timer: idle_timer}}
      end
    end
  end

  @impl true
  def handle_info(:idle_timeout, state) do
    {:stop, :normal, state}
  end

  defp cancel_idle_timeout(timer_ref) when is_reference(timer_ref) do
    Process.cancel_timer(timer_ref, info: false)
  end

  defp cancel_idle_timeout(_), do: :ok

  defp consistent?(expectation, last_pos) do
    case expectation do
      :any -> true
      :none -> last_pos == 0
      :exists -> last_pos > 0
      pos -> last_pos == pos
    end
  end

  defp schedule_idle_timeout() do
    Process.send_after(self(), :idle_timeout, @idle_timeout)
  end
end
