defmodule Fact.EventWriter do
  @compile {:no_warn_undefined, :pg}
  use GenServer
  alias Fact.Paths
  require Logger

  @moduledoc """
  Documentation for `Fact`.
  """

  

  defstruct [
    :events_dir,
    :append_log,
    :last_pos
  ]

  def start_link(opts \\ []) do

    state = %__MODULE__{
      events_dir: Paths.events,
      append_log: Paths.append_log,
      last_pos: 0
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
    last_pos = last_position(state)
    Logger.debug("#{__MODULE__} last position at #{last_pos}")
    state = %__MODULE__{ state | last_pos: last_pos }
    {:ok, state}
  end

  def handle_call({:append, event}, _from, %{events_dir: events_dir, append_log: append_log, last_pos: last_pos} = state) do

    event = Map.merge(event, %{
      id: UUID.uuid4(:hex),
      ts: DateTime.utc_now() |> DateTime.to_unix(:microsecond),
      pos: last_pos + 1
    })

    json = JSON.encode!(event)
    path = Path.join(events_dir, event.id <> ".json")
    record = JSON.decode!(json)

    :ok = File.write!(path, json, [:exclusive])
    :ok = File.write!(append_log, record["id"] <> "\n", [:append])

    :pg.get_members(:fact_indexers)
    |> Enum.each(&send(&1, {:index, record}))

    state = %__MODULE__{ state | last_pos: record["pos"] }

    {:reply, record, state}
  end

  def handle_call({:position_of, event_id}, _from, %{append_log: append_log} = state) do

    position =
      File.stream!(append_log)
      |> Stream.with_index(1)
      |> Enum.find_value(fn {line, position} ->
        if String.contains?(line, event_id), do: position, else: nil
      end)

    {:reply, position, state}

  end


  defp last_position(%{append_log: append_log}) do
    File.stream!(append_log)
    |> Enum.reduce(0, fn _line, pos -> pos + 1 end)
  end

end
