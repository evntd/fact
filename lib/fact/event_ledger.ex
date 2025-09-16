defmodule Fact.EventLedger do
  @moduledoc false

  use GenServer
  use Fact.EventKeys
  require Logger

  @registry_key {:via, Registry, {Fact.EventLedgerRegistry, :ledger}}

  defstruct [:path, :last_pos]

  def start_link(opts) do
    # TODO: Factor configuration out to the application.
    ledger_opts = Application.get_env(:fact, :ledger)
    path = Keyword.fetch!(ledger_opts, :path)
    state = %__MODULE__{path: path}
    start_opts = Keyword.put(opts, :name, @registry_key)
    GenServer.start_link(__MODULE__, state, start_opts)
  end

  def init(%__MODULE__{path: path} = state) do
    ensure_paths!(path)
    last_pos = load_position(path)
    {:ok, %__MODULE__{state | last_pos: last_pos}}
  end

  def last_position() do
    GenServer.call(@registry_key, :last_position)
  end

  def stream!(opts \\ []) do
    GenServer.call(@registry_key, {:stream!, opts})
  end

  def handle_call(:last_position, _from, %__MODULE__{last_pos: last_pos} = state) do
    {:reply, last_pos, state}
  end

  def handle_call(
        {:commit, events, expected_position},
        _from,
        %__MODULE__{last_pos: last_pos, path: path} = state
      ) do
    if expected_position != last_pos do
      {:reply, {:error, {:concurrency, expected: expected_position, actual: last_pos}}, state}
    else
      # Ensure all events have sequential positions, reduce all the event ids into lines, and track the final position.
      {sequential?, event_ids_list, final_pos} =
        Enum.reduce_while(events, {true, [], last_pos}, fn event, {_, acc, pos} ->
          expected = pos + 1

          if event[@event_store_position] == expected do
            {:cont, {true, [acc, event[@event_id], "\n"], expected}}
          else
            {:halt, {false, acc, pos}}
          end
        end)

      if sequential? do
        event_ids_to_write = IO.iodata_to_binary(event_ids_list)
        File.write!(path, event_ids_to_write, [:append])
        {:reply, {:ok, final_pos}, %__MODULE__{state | last_pos: final_pos}}
      else
        {:reply, {:error, {:store_positions_not_sequential, final_pos}}, state}
      end
    end
  end

  def handle_call({:stream!, opts}, _from, %__MODULE__{path: path} = state) do
    direction = Keyword.get(opts, :direction, :forward)

    case direction do
      :forward ->
        event_ids = Fact.IndexFileReader.read_forward(path)
        {:reply, event_ids, state}

      :backward ->
        event_ids = Fact.IndexFileReader.read_backward(path)
        {:reply, event_ids, state}

      other ->
        raise ArgumentError, "unknown direction #{inspect(other)}"
    end
  end

  defp ensure_paths!(path) do
    File.mkdir_p!(Path.dirname(path))
    unless File.exists?(path), do: File.write!(path, "")
  end

  defp load_position(path), do: File.stream!(path) |> Enum.count()
end
