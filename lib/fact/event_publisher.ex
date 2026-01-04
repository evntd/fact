defmodule Fact.EventPublisher do
  use GenServer

  @type appended_message :: {:appended, Fact.Types.record()}

  @all_events "*"

  def publish_appended(%Fact.Context{} = context, record_ids) do
    GenServer.cast(Fact.Context.via(context, __MODULE__), {:publish_appended, record_ids})
  end

  def start_link(options \\ []) do
    {opts, start_opts} = Keyword.split(options, [:database_id])

    GenServer.start_link(__MODULE__, opts, start_opts)
  end

  def subscribe(%Fact.Context{} = context, {:stream, stream}) when is_binary(stream) do
    do_subscribe(context, stream)
  end

  def subscribe(%Fact.Context{} = context, :all), do: do_subscribe(context, @all_events)

  defp do_subscribe(%Fact.Context{} = context, topic) do
    Phoenix.PubSub.subscribe(Fact.Context.pubsub(context), topic)
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
  def handle_cast({:publish_appended, record_ids}, %{database_id: id} = state) do
    with {:ok, context} <- Fact.Supervisor.get_context(id) do
      pubsub = Fact.Context.pubsub(context)

      Enum.each(record_ids, fn record_id ->
        {^record_id, event} = record = Fact.Database.read(context, record_id)
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
