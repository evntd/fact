defmodule Fact.Seam.Encoder.Raw.V1 do
  use Fact.Seam.Encoder,
    family: :raw,
    version: 1

  defstruct []

  @impl true
  def encode(%__MODULE__{}, content, _opts) when is_binary(content), do: {:ok, content}

  def encode(%__MODULE__{}, content, _opts), do: {:error, {:encode_error, content}}
end
