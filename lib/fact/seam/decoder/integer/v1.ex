defmodule Fact.Seam.Decoder.Integer.V1 do
  use Fact.Seam.Decoder,
    family: :integer,
    version: 1

  defstruct []

  @impl true
  def decode(%__MODULE__{}, binary) when is_binary(binary) do
    {:ok, String.to_integer(binary)}
  rescue
    ArgumentError ->
      {:error, {:decode, binary}}
  end

  def decode(%__MODULE__{}, value), do: {:error, {:decode, value}}
end
