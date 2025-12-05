defmodule Fact.Storage.Format.Json do
  @moduledoc """
  A JSON-based event encoding format for `Fact.Storage`.
    
  This module implements the `Fact.Storage.Format` behaviour and provides
  a simple, efficient JSON encoder/decorder for event records.

  It is typically used as the default or fallback format. Events written  
  to disk are encoded as JSON strings, and events read from disk are decoded
  back into Elixir maps.
      
  ## Usage

  To use this format explicitly when starting a Fact instance:

      Fact.start_link(:my_instance, format: Fact.Storage.Format.Json)

  When enabled, all events persisted through `Fact.Storage` will be encoded
  using `encode/1`, and all events read back will be processed through
  `decode/1`.
  
  ## Behaviour

  Implements:

    * `c:Fact.Storage.Format.encode/1`
    * `c:Fact.Storage.Format.decode/1`

  ## Examples

  Encoding an event:

      iex> Fact.Storage.Format.Json.encode(%{type: "UserRegistered", data: %{id: 1}})
      ~s({"data":{"id":1},"type":"UserRegistered"})

  Decoding an event:

      iex> Fact.Storage.Format.Json.decode(~s({"type": "UserRegistered", "data": {"id": 1}}))
      %{"data" => %{"id" => 1}, "type" => "UserRegistered"}
  """

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
