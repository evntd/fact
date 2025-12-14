defmodule Fact.Names do
  @moduledoc false

  def registry(instance), do: :"#{instance}.Fact.Registry"
  
  def via(instance, key) do
    {:via, Registry, {registry(instance), key}}
  end
end
