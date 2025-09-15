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

  def append(event) do
    GenServer.call(__MODULE__, {:append, event})
  end

  def append(stream, event) do
    GenServer.call(__MODULE__, {:append, Map.merge(event, %{stream: stream})})
  end

  def init(state) do
    last_pos = Fact.EventLedger.last_position()
    {:ok, %__MODULE__{state | last_pos: last_pos}}
  end

  def handle_call({:append, event}, _from, %{events_dir: events_dir, last_pos: last_pos} = state) do
    # TODO: The caller should provide the expected_position, but for now just get it state.    
    prepared_event =
      Map.merge(event, %{
        @event_id => UUID.uuid4(:hex),
        @event_store_timestamp => DateTime.utc_now() |> DateTime.to_unix(:microsecond),
        @event_store_position => last_pos + 1
      })

    json = JSON.encode!(prepared_event)
    path = Path.join(events_dir, prepared_event[@event_id] <> ".json")
    recorded_event = JSON.decode!(json)

    :ok = File.write!(path, json, [:exclusive])

    {:ok, position} = GenServer.call(@ledger, {:commit, [recorded_event], last_pos})

    # TODO: if commit fails, there will be some extra json files laying around on disk.
    # They could be cleaned up. But if they are not referenced within the ledger, the system will ignore them.

    :pg.get_members(:fact_indexers)
    |> Enum.each(&send(&1, {:index, recorded_event}))

    {:reply, recorded_event, %__MODULE__{state | last_pos: position}}
  end

  defp ensure_paths!() do
    File.mkdir_p!(Paths.events())
  end
end
