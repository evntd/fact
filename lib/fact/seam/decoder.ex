defmodule Fact.Seam.Decoder do
  use Fact.Seam

  @callback decode(t(), binary()) :: term()
end
