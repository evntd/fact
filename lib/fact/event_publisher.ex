defmodule Fact.EventPublisher do
  @moduledoc """
  TODO
  """
  use Fact.Types

  @type record_message :: {:event_record, Fact.Types.record()}

  @all_events "*"

  def subscribe(%Fact.Instance{} = instance, {:stream, stream}) when is_binary(stream) do
    do_subscribe(instance, stream)
  end

  def subscribe(%Fact.Instance{} = instance, :all), do: do_subscribe(instance, @all_events)

  defp do_subscribe(%Fact.Instance{} = instance, topic) do
    Phoenix.PubSub.subscribe(Fact.Instance.pubsub(instance), topic)
  end

  def publish(%Fact.Instance{} = instance, event_ids) when is_list(event_ids) do
    Enum.each(event_ids, &publish(instance, &1))
    :ok
  end

  def publish(%Fact.Instance{} = instance, event_id) when is_binary(event_id) do
    record = Fact.Storage.read_event!(instance, event_id)
    message = {:event_record, record}
    Phoenix.PubSub.broadcast(Fact.Instance.pubsub(instance), @all_events, message)

    case stream_id(record) do
      nil ->
        :ok

      stream ->
        Phoenix.PubSub.broadcast(Fact.Instance.pubsub(instance), stream, message)
    end

    :ok
  end

  defp stream_id({_, event}), do: event[@event_stream]
end
