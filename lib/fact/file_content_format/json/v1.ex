defmodule Fact.FileContentFormat.Json.V1 do
  @behaviour Fact.FileContentFormat

  defstruct []

  @impl true
  def id(), do: :json

  @impl true
  def version(), do: 1

  @impl true
  def metadata(), do: %{}

  @impl true
  def init(_metadata), do: %__MODULE__{}

  @impl true
  def normalize_options(%{} = _options), do: {:ok, %{}}

  cond do
    Code.ensure_loaded?(Elixir.JSON) ->
      @impl true
      def can_decode?(_format), do: true

      @impl true
      def can_decode?(_format, _binary), do: true

      @impl true
      def can_encode?(_format), do: true

      @impl true
      def can_encode?(_format, _content), do: true

      @impl true
      def decode(_format, binary), do: Elixir.JSON.decode(binary)

      @impl true
      def encode(_format, content) do
        try do
          {:ok, Elixir.JSON.encode!(content)}
        rescue
          e -> {:error, e}
        end
      end

    Code.ensure_loaded?(Jason) ->
      @impl true
      def can_decode?(_format), do: true

      @impl true
      def can_decode?(_format, _binary), do: true

      @impl true
      def can_encode?(_format), do: true

      @impl true
      def can_encode?(_format, _content), do: true

      @impl true
      def decode(_format, binary), do: Jason.decode(binary)

      @impl true
      def encode(_format, event_record), do: Jason.encode(event_record)

    true ->
      @impl true
      def can_decode?(_format), do: false

      @impl true
      def can_decode?(_format, _binary), do: false

      @impl true
      def can_encode?(_format), do: false

      @impl true
      def can_encode?(_format, _content), do: false

      @impl true
      def decode(_format, binary), do: {:error, :no_json_impl}

      @impl true
      def encode(_format, event_record), do: {:error, :no_json_impl}
  end
end
