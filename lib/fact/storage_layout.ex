defmodule Fact.StorageLayout do
  use Fact.Seam

  @callback init_storage(format :: t(), root :: Path.t()) :: :ok | {:error, term()}
  @callback records_path(format :: t(), root :: Path.t()) :: Path.t()
  @callback indices_path(format :: t(), root :: Path.t()) :: Path.t()
  @callback ledger_path(format :: t(), root :: Path.t()) :: Path.t()

  def records_path(%Fact.Context{
        database_path: root,
        storage_layout: %Fact.Seam.Instance{module: mod, struct: s}
      }) do
    mod.records_path(s, root)
  end

  def record_path(context, record_id) do
    Path.join(records_path(context), record_id)
  end

  def indices_path(%Fact.Context{
        database_path: root,
        storage_layout: %Fact.Seam.Instance{module: mod, struct: s}
      }) do
    mod.indices_path(s, root)
  end

  def ledger_path(%Fact.Context{
        database_path: root,
        storage_layout: %Fact.Seam.Instance{module: mod, struct: s}
      }) do
    mod.ledger_path(s, root)
  end
end
