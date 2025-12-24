defmodule Fact.Seam.StorageLayout do
  use Fact.Seam

  @callback init_storage(t(), Path.t()) :: :ok | {:error, term()}
  @callback records_path(t(), Path.t()) :: Path.t()
  @callback indices_path(t(), Path.t()) :: Path.t()
  @callback ledger_path(t(), Path.t()) :: Path.t()
end
