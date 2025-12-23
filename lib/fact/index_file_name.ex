defmodule Fact.IndexFileName do
  use Fact.Seam

  @callback filename(format :: t(), index_value :: Fact.EventIndexer.index_value()) :: Path.t()
end
