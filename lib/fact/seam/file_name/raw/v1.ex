defmodule Fact.Seam.FileName.Raw.V1 do
  use Fact.Seam.FileName,
    family: :raw,
    version: 1

  defstruct []

  @impl true
  def get(%__MODULE{}, value, _opts), do: value
end
