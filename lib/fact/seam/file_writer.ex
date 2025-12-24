defmodule Fact.Seam.FileWriter do
  use Fact.Seam

  @callback open(impl :: t(), path :: Path.t()) :: {:ok, term()} | {:error, term()}
  @callback write(impl :: t(), handle :: term(), content :: iodata()) :: :ok | {:error, term()}
  @callback close(impl :: t(), handle :: term()) :: :ok
  @callback finalize(impl :: t(), handle :: term()) :: :ok | {:error, term()}
end
