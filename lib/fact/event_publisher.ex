defmodule Fact.EventPublisher do
  use GenServer

  @type appended_message :: {:appended, Fact.Types.record()}

  @all_events "*"

  def publish_appended(database_id, record_ids) do
    GenServer.cast(Fact.Context.via(database_id, __MODULE__), {:publish_appended, record_ids})
  end

  def start_link(options \\ []) do
    {opts, start_opts} = Keyword.split(options, [:database_id])

    GenServer.start_link(__MODULE__, opts, start_opts)
  end

  def subscribe(database_id, {:stream, stream}) when is_binary(stream) do
    do_subscribe(database_id, stream)
  end

  def subscribe(database_id, :all), do: do_subscribe(database_id, @all_events)

  defp do_subscribe(database_id, topic) do
    Phoenix.PubSub.subscribe(Fact.Context.pubsub(database_id), topic)
  end

  @impl true
  def init(opts) do
    database_id = Keyword.fetch!(opts, :database_id)

    state = %{
      database_id: database_id
    }

    {:ok, state}
  end

  @impl true
  def handle_cast({:publish_appended, record_ids}, %{database_id: database_id} = state) do
    with {:ok, context} <- Fact.Registry.get_context(database_id) do
      pubsub = Fact.Context.pubsub(database_id)

      Enum.each(record_ids, fn record_id ->
        {^record_id, event} = record = Fact.Database.read_record(database_id, record_id)
        message = {:appended, record}
        Phoenix.PubSub.broadcast(pubsub, @all_events, message)

        case Fact.RecordFile.Schema.get_event_stream_id(context, event) do
          nil ->
            :ok

          stream ->
            Phoenix.PubSub.broadcast(pubsub, stream, message)
        end
      end)
    end

    {:noreply, state}
  end
end
