defmodule Fact.Seam.Decoder.Raw.V1 do
  use Fact.Seam.Decoder,
    family: :raw,
    version: 1

  @type t :: %__MODULE__{}

  defstruct []

  @impl true
  def decode(%__MODULE__{}, binary) when is_binary(binary), do: binary
end
