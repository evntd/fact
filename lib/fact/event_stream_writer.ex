defmodule Fact.EventStreamWriter do
  @moduledoc """
  A per-stream, on-demand GenServer responsible for serializing writes to an event stream. 
  It ensures that events are appended in order, enriched with stream metadata, and committed atomically.
  """
  use GenServer
  use Fact.EventKeys
  import Fact.Names
  require Logger

  @idle_timeout :timer.minutes(1)

  defstruct [:instance, :event_stream, :last_pos, :idle_timer]

  def child_spec(opts) do
    instance = Keyword.fetch!(opts, :instance)
    event_stream = Keyword.fetch!(opts, :event_stream)

    %{
      id: {__MODULE__, {instance, event_stream}},
      start: {__MODULE__, :start_link, [opts]},
      restart: :temporary,
      shutdown: 5000,
      type: :worker
    }
  end

  def start_link(opts) do
    instance = Keyword.fetch!(opts, :instance)
    event_stream = Keyword.fetch!(opts, :event_stream)
    start_opts = Keyword.put(opts, :name, via_event_stream(instance, event_stream))
    GenServer.start_link(__MODULE__, [instance: instance, event_stream: event_stream], start_opts)
  end

  @spec append(
          instance :: atom(),
          events :: list(Fact.Types.event()) | Fact.Types.event(),
          event_stream :: String.t(),
          opts :: keyword
        ) ::
          {:ok, pos_integer()} | {:error, term()}

  def append(instance, events, event_stream, opts \\ [])

  def append(instance, %{} = event, event_stream, opts),
    do: append(instance, [event], event_stream, opts)

  def append(instance, events, event_stream, opts) do
    {call_opts, append_opts} = Keyword.split(opts, [:timeout])
    timeout = Keyword.get(call_opts, :timeout, 5000)

    ensure_started(instance, event_stream)

    GenServer.call(
      via_event_stream(instance, event_stream),
      {:append, events, append_opts},
      timeout
    )
  end

  defp ensure_started(instance, event_stream) do
    case Registry.lookup(event_stream_registry(instance), event_stream) do
      [] ->
        DynamicSupervisor.start_child(
          via(instance, Fact.EventStreamWriterSupervisor),
          {__MODULE__, [instance: instance, event_stream: event_stream]}
        )

      _ ->
        :ok
    end
  end

  # Server callbacks

  @impl true
  def init(opts) do
    instance = Keyword.fetch!(opts, :instance)
    event_stream = Keyword.fetch!(opts, :event_stream)

    state = %__MODULE__{
      instance: instance,
      event_stream: event_stream,
      last_pos: 0,
      idle_timer: schedule_idle_timeout()
    }

    {:ok, state, {:continue, :load_position}}
  end

  @impl true
  def handle_continue(:load_position, %{instance: instance, event_stream: event_stream} = state) do
    last_pos = Fact.EventStreamIndexer.last_stream_position(instance, event_stream)
    {:noreply, %{state | last_pos: last_pos}}
  end

  @impl true
  def handle_call(
        {:append, events, opts},
        _from,
        %{instance: instance, event_stream: event_stream, last_pos: last_pos} = state
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

      case Fact.EventLedger.commit(instance, enriched_events) do
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
