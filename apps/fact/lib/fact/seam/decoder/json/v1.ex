defmodule Fact.Seam.Decoder.Json.V1 do
  @moduledoc """
  A JSON decoder implementation.

  Supports either the `Elixir.JSON` or `Jason` libraries if available.
  If neither library is loaded, decoding will return `{:error, :no_json_impl}`.
  """
  use Fact.Seam.Decoder,
    family: :json,
    version: 1

  defstruct []

  cond do
    Code.ensure_loaded?(Elixir.JSON) ->
      @impl true
      def decode(%__MODULE__{}, binary, _opts), do: Elixir.JSON.decode(binary)

    Code.ensure_loaded?(Jason) ->
      @impl true
      def decode(%__MODULE__{}, binary, _opts), do: Jason.decode(binary)

    true ->
      @impl true
      def decode(%__MODULE__{}, binary, _opts), do: {:error, :no_json_impl}
  end
end
