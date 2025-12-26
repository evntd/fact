defmodule Fact.Seam.Decoder do
  use Fact.Seam

  @callback decode(impl :: t(), value :: binary()) ::
              {:ok, decoded :: term()} | {:error, reason :: term()}
end
