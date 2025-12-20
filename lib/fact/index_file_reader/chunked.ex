defmodule Fact.IndexFileReader.Chunked do
  @moduledoc """
  Not yet implemented, but will provide more efficient reads.
  """

  @doc """
  Raises a `Fact.DatabaseError`

      iex> Fact.IndexFileReader.Chunked.forward("tmp/mydb/events/00000000000000000000000000000000", :start, 32)
      ** (Fact.DatabaseError) not implemented

      iex> Fact.IndexFileReader.Chunked.backward("tmp/mydb/events/00000000000000000000000000000000", :end, 32)
      ** (Fact.DatabaseError) not implemented
  """
  def forward(_path, _position, _record_size) do
    raise Fact.DatabaseError, message: "not implemented"
  end

  def backward(_path, _position, _record_size) do
    raise Fact.DatabaseError, message: "not implemented"
  end
end
