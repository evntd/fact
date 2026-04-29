defmodule Fact.Seam.Encoder.Integer.V1 do
  @moduledoc """
  Integer encoder implementation for event records.

  Converts an integer value into its string representation. Returns `{:ok, string}` 
  if the input is a valid integer.
  """
  use Fact.Seam.Encoder,
    family: :integer,
    version: 1

  defstruct []

  @impl true
  def encode(%__MODULE__{}, content, _opts) when is_integer(content) do
    {:ok, Integer.to_string(content)}
  end
end
