defmodule Fact.EventPublisher do
  @moduledoc """
  TODO
  """
  use Fact.Types

  @type record_message :: {:event_record, Fact.Types.record()}

  @all_events "*"

  def subscribe(%Fact.Context{} = context, {:stream, stream}) when is_binary(stream) do
    do_subscribe(context, stream)
  end

  def subscribe(%Fact.Context{} = context, :all), do: do_subscribe(context, @all_events)

  defp do_subscribe(%Fact.Context{} = context, topic) do
    Phoenix.PubSub.subscribe(Fact.Context.pubsub(context), topic)
  end

  def publish(%Fact.Context{} = context, event_ids) when is_list(event_ids) do
    Enum.each(event_ids, &publish(context, &1))
    :ok
  end

  def publish(%Fact.Context{} = context, event_id) when is_binary(event_id) do
    record = Fact.RecordFile.read(context, event_id)
    message = {:event_record, record}
    Phoenix.PubSub.broadcast(Fact.Context.pubsub(context), @all_events, message)

    case stream_id(record) do
      nil ->
        :ok

      stream ->
        Phoenix.PubSub.broadcast(Fact.Context.pubsub(context), stream, message)
    end

    :ok
  end

  defp stream_id({_, event}), do: event[@event_stream]
end
