defmodule Fact.IndexFileReader do
  @moduledoc false

  def read_forward(path) do
    File.stream!(path) |> Stream.map(&String.trim/1)
  end

  defdelegate read_backward(path), to: Fact.IndexFileReader.Backwards.Line, as: :read
end
