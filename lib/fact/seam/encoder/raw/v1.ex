defmodule Fact.Seam.Encoder.Raw.V1 do
  @before_compile Fact.Seam.Capabilities
  use Fact.Seam.Encoder,
    family: :raw,
    version: 1

  @type t :: %__MODULE__{}

  defstruct []

  @impl true
  def encode(%__MODULE__{}, content) when is_binary(content), do: content
end
