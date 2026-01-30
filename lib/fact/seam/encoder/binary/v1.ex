defmodule Fact.Seam.Encoder.Binary.V1 do
  use Fact.Seam.Encoder,
    family: :binary,
    version: 1

  defstruct []

  def encode(%__MODULE__{}, content, _opts) do
    {:ok, :erlang.term_to_binary(content)}
  end
end
