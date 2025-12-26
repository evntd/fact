defmodule Fact.Seam.FileContent do
  use Fact.Seam

  @callback decode(t(), binary()) :: term()
  @callback encode(t(), term()) :: iodata()
end
