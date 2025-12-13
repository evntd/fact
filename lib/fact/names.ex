defmodule Fact.Names do
  @moduledoc false

  def registry(instance), do: :"#{instance}.Fact.Registry"
  def subscription(instance), do: :"#{instance}.Fact.EventPublisher"

  def via(instance, key) do
    {:via, Registry, {registry(instance), key}}
  end
end
