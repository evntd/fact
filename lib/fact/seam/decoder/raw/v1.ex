defmodule Fact.Seam.Decoder.Raw.V1 do
  @before_compile Fact.Seam.Capabilities
  use Fact.Seam.Decoder,
    family: :raw,
    version: 1

  @type t :: %__MODULE__{}

  defstruct []

  @impl true
  def decode(%__MODULE__{}, value) when is_binary(value), do: {:ok, value}
  def decode(%__MODULE__{}, value), do: {:error, {:decode, value}}
end
