defmodule Fact.Seam.StorageLayout do
  use Fact.Seam

  @callback path(t(), opts :: keyword()) :: {:ok, Path.t()} | {:error, term()}
  @callback records_path(t(), opts :: keyword()) :: {:ok, Path.t()} | {:error, term()}
  @callback indices_path(t(), opts :: keyword()) :: {:ok, Path.t()} | {:error, term()}
  @callback ledger_path(t(), opts :: keyword()) :: {:ok, Path.t()} | {:error, term()}
end
