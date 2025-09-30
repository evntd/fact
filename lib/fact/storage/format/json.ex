defmodule Fact.Storage.Format.Json do
  @moduledoc false
  @behaviour Fact.Storage.Format

  @impl true
  def encode(event) do
    JSON.encode!(event)
  end

  @impl true
  def decode(encoded_event) do
    JSON.decode!(encoded_event)
  end
end
