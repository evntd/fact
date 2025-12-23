defmodule Fact.StorageLayout do
  @allowed_formats [{:default, 1}]
  @default_format {:default, 1}
  @format_registry Fact.StorageLayout.Registry

  def allowed_formats(), do: @allowed_formats
  def default_format(), do: @default_format
  def format_registry(), do: @format_registry

  def records_path(%Fact.Context{
        database_path: root,
        storage_layout_format: %Fact.Seam.Instance{module: mod, struct: s}
      }) do
    mod.records_path(s, root)
  end

  def record_path(context, record_id) do
    Path.join(records_path(context), record_id)
  end

  def indices_path(%Fact.Context{
        database_path: root,
        storage_layout_format: %Fact.Seam.Instance{module: mod, struct: s}
      }) do
    mod.indices_path(s, root)
  end

  def ledger_path(%Fact.Context{
        database_path: root,
        storage_layout_format: %Fact.Seam.Instance{module: mod, struct: s}
      }) do
    mod.ledger_path(s, root)
  end
end
