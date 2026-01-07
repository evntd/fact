defmodule Fact.Seam.FileName.Raw.V1 do
  @moduledoc """
  A raw file name implementation that returns the input value unchanged.

  This `Fact.Seam.FileName` implementation simply passes through the given value as the file name.
  """
  use Fact.Seam.FileName,
    family: :raw,
    version: 1

  defstruct []

  @impl true
  def get(%__MODULE{}, value, _opts), do: {:ok, value}
end
