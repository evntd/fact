defmodule Fact.Seam.FileName do
  use Fact.Seam

  @callback for(t(), term()) :: Path.t() | {:error, term()}
end
