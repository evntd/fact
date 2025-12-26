defmodule Fact.Seam.Decoder.Integer.V1 do
  use Fact.Seam.Decoder,
    family: :integer,
    version: 1

  @type t :: %__MODULE__{}

  defstruct []

  @impl true
  def decode(%__MODULE__{}, binary) when is_binary(binary) do
    String.to_integer(binary)
  end
end
