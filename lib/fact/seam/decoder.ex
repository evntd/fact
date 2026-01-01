defmodule Fact.Seam.Decoder do
  use Fact.Seam

  @callback decode(impl :: t(), value :: binary(), opts :: keyword()) ::
              {:ok, decoded :: term()} | {:error, reason :: term()}
end
