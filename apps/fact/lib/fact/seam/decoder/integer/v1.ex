defmodule Fact.Seam.Decoder.Integer.V1 do
  @moduledoc """
  A decoder for integers.

  Converts a binary string representation of an integer into an actual integer.
  Returns `{:error, {:decode, value}}` if the input cannot be converted.
  """
  use Fact.Seam.Decoder,
    family: :integer,
    version: 1

  defstruct []

  @impl true
  def decode(%__MODULE__{}, binary, _opts) when is_binary(binary) do
    {:ok, String.to_integer(binary)}
  rescue
    ArgumentError ->
      {:error, {:decode, binary}}
  end

  def decode(%__MODULE__{}, value, _opts), do: {:error, {:decode, value}}
end
