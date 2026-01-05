defmodule Fact.CatchUpSubscription.All do
  use Fact.CatchUpSubscription

  def start_link(options) do
    {opts, start_opts} = Keyword.split(options, [:database_id, :subscriber, :position])

    database_id = Keyword.fetch!(opts, :database_id)
    subscriber = Keyword.fetch!(opts, :subscriber)
    position = Keyword.get(opts, :position, 0)

    GenServer.start_link(__MODULE__, {database_id, subscriber, :all, position}, start_opts)
  end

  @impl true
  def subscribe(database_id, :all) do
    Fact.EventPublisher.subscribe(database_id, :all)
  end

  @impl true
  def get_position(database_id, :all, event) do
    with {:ok, context} <- Fact.Registry.get_context(database_id) do
      Fact.Event.Schema.get_event_store_position(context, event)
    end
  end

  @impl true
  def high_water_mark(database_id, :all) do
    Fact.Database.last_position(database_id)
  end

  @impl true
  def replay(database_id, :all, from_pos, to_pos, deliver_fun) do
    with {:ok, context} <- Fact.Registry.get_context(database_id) do
      Fact.Database.read_ledger(database_id, position: from_pos, result_type: :record)
      |> Stream.take_while(fn {_, event} ->
        Fact.Event.Schema.get_event_store_position(context, event) <= to_pos
      end)
      |> Enum.each(&deliver_fun.(&1))
    end
  end

  @impl true
  def handle_info({:appended, record}, state) do
    buffer_or_deliver(record, state)
  end
end
