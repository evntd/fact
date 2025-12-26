defmodule Fact.Seam.FileContent.Json.V1 do
  use Fact.Seam.FileContent,
    family: :json,
    version: 1

  defstruct []

  cond do
    Code.ensure_loaded?(Elixir.JSON) ->
      @impl true
      def decode(%__MODULE__{}, binary), do: Elixir.JSON.decode(binary)

      @impl true
      def encode(%__MODULE__{}, content) do
        try do
          {:ok, Elixir.JSON.encode!(content)}
        rescue
          e -> {:error, e}
        end
      end

    Code.ensure_loaded?(Jason) ->
      @impl true
      def decode(%__MODULE__{}, binary), do: Jason.decode(binary)

      @impl true
      def encode(%__MODULE__{}, event_record), do: Jason.encode(event_record)

    true ->
      @impl true
      def decode(%__MODULE__{}, binary), do: {:error, :no_json_impl}

      @impl true
      def encode(%__MODULE__{}, event_record), do: {:error, :no_json_impl}
  end
end
