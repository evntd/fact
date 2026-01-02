defmodule Fact.Seam.EventId do
  use Fact.Seam

  @callback generate(state :: t(), opts :: keyword()) :: binary() | {:error, term()}
end
