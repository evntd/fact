defmodule Fact.JSON do
  @moduledoc false

  cond do
    Code.ensure_loaded?(JSON) ->
      def encode!(term), do: Elixir.JSON.encode!(term)
      def decode!(json), do: Elixir.JSON.decode!(json)

    Code.ensure_loaded?(Jason) ->
      def encode!(term), do: Jason.encode!(term)
      def decode!(json), do: Jason.decode!(json)

    true ->
      def encode!(_), do: raise("No JSON implementation available. Add :jason dependency.")
      def decode!(_), do: raise("No JSON implementation available. Add :jason dependency.")
  end
end
