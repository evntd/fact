defmodule Fact.Seam.FileContent do
  use Fact.Seam

  @callback can_decode?(t()) :: boolean()
  @callback can_decode?(t(), binary()) :: boolean()
  @callback can_encode?(t()) :: boolean()
  @callback can_encode?(t(), term()) :: boolean()
  @callback decode(t(), binary()) :: term()
  @callback encode(t(), term()) :: iodata()
end
