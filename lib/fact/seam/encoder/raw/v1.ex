defmodule Fact.Seam.Encoder.Raw.V1 do
  use Fact.Seam.Encoder,
    family: :raw,
    version: 1

  defstruct []

  @impl true
  def encode(%__MODULE__{}, content) when is_binary(content), do: content
end
