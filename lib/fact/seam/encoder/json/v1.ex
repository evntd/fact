defmodule Fact.Seam.Encoder.Json.V1 do
  use Fact.Seam.Encoder,
    family: :json,
    version: 1

  defstruct []

  cond do
    Code.ensure_loaded?(Elixir.JSON) ->
      @impl true
      def encode(%__MODULE__{}, content, _opts) do
        try do
          {:ok, Elixir.JSON.encode!(content)}
        rescue
          e -> {:error, e}
        end
      end

    Code.ensure_loaded?(Jason) ->
      @impl true
      def encode(%__MODULE__{}, event_record, _opts), do: Jason.encode(event_record)

    true ->
      @impl true
      def encode(%__MODULE__{}, event_record, _opts), do: {:error, :no_json_impl}
  end
end
