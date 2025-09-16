defmodule Fact.EventWriter do
  use GenServer
  use Fact.EventKeys

  alias Fact.Paths
  require Logger

  @compile {:no_warn_undefined, :pg}
  @ledger {:via, Registry, {Fact.EventLedgerRegistry, :ledger}}

  defstruct [
    :events_dir,
    :last_pos
  ]

  def start_link(opts \\ []) do
    ensure_paths!()

    state = %__MODULE__{
      events_dir: Paths.events()
    }

    opts = Keyword.put_new(opts, :name, __MODULE__)

    GenServer.start_link(__MODULE__, state, opts)
  end

  def append(events, opts \\ [])
  def append(event, opts) when is_map(event), do: append([event], opts)

  def append(events, opts) when is_list(events) do
    GenServer.call(__MODULE__, {:append, events, opts})
  end

  def init(state) do
    last_pos = Fact.EventLedger.last_position()
    {:ok, %__MODULE__{state | last_pos: last_pos}}
  end

  def handle_call(
        {:append, events, opts},
        _from,
        %{events_dir: events_dir, last_pos: last_pos} = state
      ) do
    # Enrich with @event_stream key if specified
    enriched_events =
      case Keyword.get(opts, :stream) do
        nil ->
          events

        stream ->
          Enum.map(events, &Map.put(&1, @event_stream, stream))
      end

    # Determine expected position
    expected_pos =
      case Keyword.get(opts, :expectation, :none) do
        :none -> last_pos
        pos when is_integer(pos) -> pos
      end

    start_pos = expected_pos + 1

    {persisted_event_refs, next_pos} =
      Enum.map_reduce(enriched_events, start_pos, fn event, event_pos ->
        event_id = UUID.uuid4(:hex)

        prepared_event =
          Map.merge(event, %{
            @event_id => event_id,
            @event_store_position => event_pos,
            @event_store_timestamp => DateTime.utc_now() |> DateTime.to_unix(:microsecond)
          })

        encoded_event = JSON.encode!(prepared_event)
        event_path = Path.join(events_dir, event_id <> ".json")
        :ok = File.write!(event_path, encoded_event, [:exclusive])

        {{event_id, event_pos}, event_pos + 1}
      end)

    {:ok, position} = GenServer.call(@ledger, {:commit, persisted_event_refs, expected_pos})

    # TODO: if commit fails, there will be some extra json files laying around on disk.
    # They could be cleaned up. But if they are not referenced within the ledger, the system will ignore them.

    :ok = Fact.EventIndexerManager.index(persisted_event_refs)

    {:reply, {:ok, position}, %__MODULE__{state | last_pos: position}}
  end

  defp ensure_paths!() do
    File.mkdir_p!(Paths.events())
  end
end
