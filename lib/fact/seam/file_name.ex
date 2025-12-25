defmodule Fact.Seam.FileName do
  use Fact.Seam

  @callback get(t(), term()) :: Path.t() | {:error, term()}
end
