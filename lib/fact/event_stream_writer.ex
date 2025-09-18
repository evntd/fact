defmodule Fact.EventStreamWriter do
  @moduledoc false

  use GenServer
  use Fact.EventKeys

  def start_link(event_stream) do
    GenServer.start_link(__MODULE__, event_stream, name: via_tuple(event_stream))
  end

  def append(event_stream, events, opts \\ []) do
    {call_opts, append_opts} = Keyword.split(opts, [:timeout])
    timeout = Keyword.get(call_opts, :timeout, 5000)
    GenServer.call(via_tuple(event_stream), {:append, events, append_opts}, timeout)
  end

  defp via_tuple(event_stream) do
    {:via, Registry, {Fact.EventStreamRegistry, event_stream}}
  end

  # Server callbacks

  @impl true
  def init(event_stream) do
    {:ok, %{event_stream: event_stream}, {:continue, :load_position}}
  end

  @impl true
  def handle_continue(:load_position, %{event_stream: event_stream} = state) do
    last_pos = Fact.EventIndexerManager.last_position(Fact.EventStreamIndexer, event_stream)
    {:noreply, Map.put(state, :last_pos, last_pos)}
  end

  @impl true
  def handle_call(
        {:append, events, opts},
        _from,
        %{event_stream: event_stream, last_pos: last_pos} = state
      ) do
    expect = Keyword.get(opts, :expect, :any)

    if not consistent?(expect, last_pos) do
      {:reply, {:error, {:concurrency, expected: expect, actual: last_pos}}}
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
        {:ok, _last_store_pos} -> {:reply, {:ok, end_pos}, %{state | last_pos: end_pos}}
        {:error, reason} -> {:reply, {:error, reason}, state}
      end
    end
  end

  defp consistent?(expectation, last_pos) do
    case expectation do
      :any -> true
      :no_stream -> last_pos == 0
      :exists -> last_pos > 0
      pos -> last_pos == pos
    end
  end
end
