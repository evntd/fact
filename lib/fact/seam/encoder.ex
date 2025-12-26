defmodule Fact.Seam.Encoder do
  use Fact.Seam

  @callback encode(t(), term()) :: iodata()
end
