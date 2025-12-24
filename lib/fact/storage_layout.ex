defmodule Fact.StorageLayout do
  alias Fact.Context
  alias Fact.Seam.Instance
  alias Fact.Seam.StorageLayout.Registry

  def allowed_impls(), do: [{:default, 1}]
  def default_impl(), do: {:default, 1}
  def default_impl_options(), do: %{}
  def impl_registry(), do: Registry

  def records_path(%Context{
        database_path: root,
        storage_layout: %Instance{module: mod, struct: s}
      }) do
    mod.records_path(s, root)
  end

  def record_path(context, record_id) do
    Path.join(records_path(context), record_id)
  end

  def indices_path(%Context{
        database_path: root,
        storage_layout: %Instance{module: mod, struct: s}
      }) do
    mod.indices_path(s, root)
  end

  def ledger_path(%Context{
        database_path: root,
        storage_layout: %Instance{module: mod, struct: s}
      }) do
    mod.ledger_path(s, root)
  end
end
