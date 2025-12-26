defmodule Fact.Seam.Decoder.Json.V1 do
  @before_compile Fact.Seam.Capabilities
  use Fact.Seam.Decoder,
    family: :json,
    version: 1

  defstruct []

  cond do
    Code.ensure_loaded?(Elixir.JSON) ->
      @impl true
      def decode(%__MODULE__{}, binary), do: Elixir.JSON.decode(binary)

    Code.ensure_loaded?(Jason) ->
      @impl true
      def decode(%__MODULE__{}, binary), do: Jason.decode(binary)

    true ->
      @impl true
      def decode(%__MODULE__{}, binary), do: {:error, :no_json_impl}
  end
end
