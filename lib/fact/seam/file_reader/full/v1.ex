defmodule Fact.Seam.FileReader.Full.V1 do
  use Fact.Seam.FileReader,
    family: :full,
    version: 1

  @type t :: %{}

  defstruct []

  @impl true
  def read(%__MODULE__{}, path, _options) do
    case File.read(path) do
      {:ok, binary} ->
        {:ok, Stream.map([binary], & &1)}
    end
  end
end
