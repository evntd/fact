defmodule Fact.Seam.EventId do
  use Fact.Seam

  @callback generate(state :: t(), opts :: keyword()) :: {:ok, binary()} | {:error, term()}
end
