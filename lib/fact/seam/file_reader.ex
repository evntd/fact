defmodule Fact.Seam.FileReader do
  use Fact.Seam

  @callback read(impl :: t(), path :: Path.t(), opts :: keyword()) ::
              {:ok, Enumerable.t()} | {:error, term()}
end
