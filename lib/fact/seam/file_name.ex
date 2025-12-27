defmodule Fact.Seam.FileName do
  use Fact.Seam

  @callback get(t(), term(), keyword()) :: Path.t() | {:error, term()}
end
