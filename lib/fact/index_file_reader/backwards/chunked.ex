defmodule Fact.IndexFileReader.Backwards.Chunked do
  @moduledoc """
  Not yet implemented, but will provide more efficient `:backward` reads.
  """

  @doc """
  Raises a `Fact.DatabaseError`

      iex> Fact.IndexFileReader.Backwards.Chunked.read("tmp/mydb")
      ** (Fact.DatabaseError) not implemented
  """
  def read(_path) do
    raise Fact.DatabaseError, message: "not implemented"
  end
end
