defmodule Fact.IndexFileName do
  use Fact.Seam

  @callback for(t(), Fact.EventIndexer.index_value()) :: Path.t() | {:error, term()}
end
