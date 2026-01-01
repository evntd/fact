defmodule Fact.Seam.FileReader.Full.V1 do
  use Fact.Seam.FileReader,
    family: :full,
    version: 1

  defstruct []

  @impl true
  def read(%__MODULE__{}, path, _options) do
    with {:ok, binary} <- File.read(path) do
      {:ok, Stream.map([binary], & &1)}
    end
  end
end
