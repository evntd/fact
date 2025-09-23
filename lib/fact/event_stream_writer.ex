defmodule Fact.EventStreamWriter do
  @moduledoc false

  use GenServer
  use Fact.EventKeys
  require Logger

  @idle_timeout :timer.minutes(1)

  defstruct [:event_stream, :last_pos, :idle_timer]

  def start_link(event_stream) do
    GenServer.start_link(__MODULE__, event_stream, name: via_tuple(event_stream))
  end

  def child_spec(event_stream) do
    %{
      id: {__MODULE__, event_stream},
      start: {__MODULE__, :start_link, [event_stream]},
      restart: :temporary,
      shutdown: 5000,
      type: :worker
    }
  end

  def append(events, event_stream, opts \\ []) do
    {call_opts, append_opts} = Keyword.split(opts, [:timeout])
    timeout = Keyword.get(call_opts, :timeout, 5000)

    ensure_started(event_stream)
    GenServer.call(via_tuple(event_stream), {:append, events, append_opts}, timeout)
  end

  defp via_tuple(event_stream) do
    {:via, Registry, {Fact.EventStreamRegistry, event_stream}}
  end

  defp ensure_started(event_stream) do
    case Registry.lookup(Fact.EventStreamRegistry, event_stream) do
      [] ->
        DynamicSupervisor.start_child(
          Fact.EventStreamWriterSupervisor,
          {__MODULE__, event_stream}
        )

      _ ->
        :ok
    end
  end

  # Server callbacks

  @impl true
  def init(event_stream) do
    state = %__MODULE__{
      event_stream: event_stream,
      last_pos: 0,
      idle_timer: schedule_idle_timeout()
    }

    Logger.debug("starting #{event_stream} writer")
    {:ok, state, {:continue, :load_position}}
  end

  @impl true
  def handle_continue(:load_position, %{event_stream: event_stream} = state) do
    last_pos = Fact.EventIndexerManager.last_position(Fact.EventStreamIndexer, event_stream)
    {:noreply, %{state | last_pos: last_pos}}
  end

  @impl true
  def handle_call(
        {:append, events, opts},
        _from,
        %{event_stream: event_stream, last_pos: last_pos} = state
      ) do
    cancel_idle_timeout(state.idle_timer)
    idle_timer = schedule_idle_timeout()

    expect = Keyword.get(opts, :expect, :any)

    if not consistent?(expect, last_pos) do
      {:reply, {:error, {:concurrency, expected: expect, actual: last_pos}},
       %{state | idle_timer: idle_timer}}
    else
      {enriched_events, end_pos} =
        Enum.map_reduce(events, last_pos, fn event, pos ->
          next_pos = pos + 1

          enriched_event =
            Map.merge(event, %{
              @event_stream => event_stream,
              @event_stream_position => next_pos
            })

          {enriched_event, next_pos}
        end)

      case Fact.EventLedger.commit(enriched_events) do
        {:ok, _last_store_pos} ->
          {:reply, {:ok, end_pos}, %{state | idle_timer: idle_timer, last_pos: end_pos}}

        {:error, reason} ->
          {:reply, {:error, reason}, %{state | idle_timer: idle_timer}}
      end
    end
  end

  @impl true
  def handle_info(:idle_timeout, %{event_stream: event_stream} = state) do
    Logger.debug("stopping #{event_stream} writer")
    {:stop, :normal, state}
  end

  defp cancel_idle_timeout(timer_ref) when is_reference(timer_ref) do
    Process.cancel_timer(timer_ref, info: false)
  end

  defp cancel_idle_timeout(_), do: :ok

  defp consistent?(expectation, last_pos) do
    case expectation do
      :any -> true
      :no_stream -> last_pos == 0
      :exists -> last_pos > 0
      pos -> last_pos == pos
    end
  end

  defp schedule_idle_timeout() do
    Process.send_after(self(), :idle_timeout, @idle_timeout)
  end
end
