defmodule Fact.Seam.Decoder.Binary.V1 do
  use Fact.Seam.Decoder,
    family: :binary,
    version: 1

  defstruct []

  @impl true
  def decode(%__MODULE__{}, binary, _opts) do
    {:ok, :erlang.binary_to_term(binary)}
  end
end
