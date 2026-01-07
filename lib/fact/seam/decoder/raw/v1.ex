defmodule Fact.Seam.Decoder.Raw.V1 do
  @moduledoc """
  A raw decoder implementation that returns the binary value as-is.

  If the input is not binary, returns an error tuple.
  """
  use Fact.Seam.Decoder,
    family: :raw,
    version: 1

  defstruct []

  @impl true
  def decode(%__MODULE__{}, value, _opts) when is_binary(value), do: {:ok, value}
  def decode(%__MODULE__{}, value, _opts), do: {:error, {:decode, value}}
end
