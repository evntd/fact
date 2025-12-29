defmodule Fact.Seam.Decoder.Raw.V1 do
  use Fact.Seam.Decoder,
    family: :raw,
    version: 1

  defstruct []

  @impl true
  def decode(%__MODULE__{}, value) when is_binary(value), do: {:ok, value}
  def decode(%__MODULE__{}, value), do: {:error, {:decode, value}}
end
