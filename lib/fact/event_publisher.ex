defmodule Fact.EventPublisher do
  use Fact.EventKeys

  @all_events "*"

  def subscribe(instance, source \\ @all_events) do
    Phoenix.PubSub.subscribe(instance, source)
  end

  def publish(instance, event_ids) when is_list(event_ids) do
    Enum.each(event_ids, &publish(instance, &1))
    :ok
  end

  def publish(instance, event_id) when is_binary(event_id) do
    record = Fact.Storage.read_event!(instance, event_id)
    message = {:event_record, record}
    Phoenix.PubSub.broadcast(instance, @all_events, message)
    :ok
  end
end
