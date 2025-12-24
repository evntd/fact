defmodule Fact.Seam.StorageLayout do
  use Fact.Seam

  @callback init_storage(format :: t(), root :: Path.t()) :: :ok | {:error, term()}
  @callback records_path(format :: t(), root :: Path.t()) :: Path.t()
  @callback indices_path(format :: t(), root :: Path.t()) :: Path.t()
  @callback ledger_path(format :: t(), root :: Path.t()) :: Path.t()
end
