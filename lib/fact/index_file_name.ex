defmodule Fact.IndexFileName do
  use Fact.Seam

  @callback for(format :: t(), index_value :: Fact.EventIndexer.index_value()) :: Path.t()
end
