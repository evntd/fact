defmodule Fact.Seam.Encoder.Raw.V1 do
  @moduledoc """
  Standard raw encoder implementation that passes binary content through unchanged.

  This encoder only accepts binary data. Non-binary input returns an `:encode_error`.
  """
  use Fact.Seam.Encoder,
    family: :raw,
    version: 1

  defstruct []

  @impl true
  def encode(%__MODULE__{}, content, _opts) when is_binary(content), do: {:ok, content}

  def encode(%__MODULE__{}, content, _opts), do: {:error, {:encode_error, content}}
end
