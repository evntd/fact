defmodule Fact.Seam.Encoder do
  use Fact.Seam

  @callback encode(t(), term(), keyword()) :: {:ok, iodata()} | {:error, term()}
end
