defmodule Fact.CatchUpSubscription.Stream do
  use Fact.CatchUpSubscription

  def start_link(options) do
    {opts, start_opts} = Keyword.split(options, [:database_id, :subscriber, :stream, :position])

    database_id = Keyword.fetch!(opts, :database_id)
    stream = Keyword.fetch!(opts, :stream)
    subscriber = Keyword.fetch!(opts, :subscriber)
    position = Keyword.get(opts, :position, 0)

    GenServer.start_link(
      __MODULE__,
      {database_id, subscriber, {:stream, stream}, position},
      start_opts
    )
  end

  @impl true
  def subscribe(%{database_id: database_id, source: {:stream, _stream} = source}) do
    Fact.EventPublisher.subscribe(database_id, source)
  end

  @impl true
  def get_position(%{schema: schema, source: {:stream, _stream}} = _state, event) do
    event[schema.event_stream_position]
  end

  @impl true
  def high_water_mark(%{database_id: database_id, source: {:stream, stream}}) do
    Fact.EventStreamIndexer.last_stream_position(database_id, stream)
  end

  @impl true
  def replay(
        %{database_id: database_id, schema: schema, source: {:stream, stream}},
        from_pos,
        to_pos,
        deliver_fun
      ) do
    Fact.Database.read_index(database_id, {Fact.EventStreamIndexer, nil}, stream,
      position: from_pos,
      result: :record
    )
    |> Stream.take_while(fn {_, event} ->
      event[schema.event_stream_position] <= to_pos
    end)
    |> Enum.each(&deliver_fun.(&1))
  end

  @impl true
  def handle_info({:appended, record}, state) do
    buffer_or_deliver(record, state)
  end
end
