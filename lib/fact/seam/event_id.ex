defmodule Fact.Seam.EventId do
  use Fact.Seam

  @callback generate(t()) :: {:ok, binary()} | {:error, term()}
end
