defmodule Fact.Seam.FileName do
  use Fact.Seam

  @callback get(state :: t(), value :: term(), opts :: keyword()) ::
              {:ok, Path.t()} | {:error, term()}
end
