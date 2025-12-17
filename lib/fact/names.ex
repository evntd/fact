defmodule Fact.Names do
  @moduledoc false

  def registry(database_id) do
    Module.concat(Fact.Registry, database_id)
  end

  def via(database_id, key) do
    {:via, Registry, {registry(database_id), key}}
  end
end
