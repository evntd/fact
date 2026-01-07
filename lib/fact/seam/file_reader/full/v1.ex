defmodule Fact.Seam.FileReader.Full.V1 do
  @moduledoc """
  A `Fact.Seam.FileReader` implementation that reads the entire file content at once.

  The file is read as a single binary, then wrapped in a `Stream` to provide
  a consistent streaming interface for downstream consumers.
  """
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
