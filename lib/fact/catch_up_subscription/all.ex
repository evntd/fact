defmodule Fact.CatchUpSubscription.All do
  @moduledoc """
  Catch-up subscription for the all stream.

  This subscription replays every event in the database from the selected
  starting position up to the current position, delivers them to the
  subscriber, and then transitions into live mode to stream new events as
  they are appended.
  """

  use Fact.CatchUpSubscription

  def start_link(options) do
    {opts, start_opts} = Keyword.split(options, [:database_id, :subscriber, :position])

    database_id = Keyword.fetch!(opts, :database_id)
    subscriber = Keyword.get(opts, :subscriber, self())
    position = Keyword.get(opts, :position, :start)

    GenServer.start_link(__MODULE__, {database_id, subscriber, :all, position}, start_opts)
  end

  @impl true
  @doc false
  def subscribe(%{database_id: database_id} = _state) do
    Fact.EventPublisher.subscribe(database_id, :all)
  end

  @impl true
  @doc false
  def high_water_mark(%{database_id: database_id}) do
    Fact.Database.last_position(database_id)
  end

  @impl true
  @doc false
  def replay(%{database_id: database_id, schema: schema}, from_pos, to_pos, deliver_fun) do
    Fact.Database.read_ledger(database_id, position: from_pos, result: :record)
    |> Stream.take_while(fn {_, event} ->
      event[schema.event_store_position] <= to_pos
    end)
    |> Enum.each(&deliver_fun.(&1))
  end

  @impl true
  @doc false
  def handle_info({:appended, record}, state) do
    buffer_or_deliver(record, state)
  end
end
