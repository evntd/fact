defmodule Fact.Names do
  @moduledoc false

  def registry(instance), do: :"#{instance}.Fact.Registry"
  def event_stream_registry(instance), do: :"#{instance}.Fact.EventStreamRegistry"
  def event_indexer_registry(instance), do: :"#{instance}.Fact.EventIndexerRegistry"

  def subscription(instance), do: :"#{instance}.Fact.EventPublisher"

  def via(instance, key) do
    {:via, Registry, {registry(instance), key}}
  end

  def via_event_stream(instance, key) do
    {:via, Registry, {event_stream_registry(instance), key}}
  end

  def via_indexer(instance, key) do
    {:via, Registry, {event_indexer_registry(instance), key}}
  end
end
