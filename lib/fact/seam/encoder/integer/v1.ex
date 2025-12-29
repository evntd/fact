defmodule Fact.Seam.Encoder.Integer.V1 do
  use Fact.Seam.Encoder,
    family: :integer,
    version: 1

  defstruct []

  @impl true
  def encode(%__MODULE__{}, content) when is_integer(content) do
    Integer.to_string(content)
  end
end
