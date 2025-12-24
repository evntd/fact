defmodule Fact.StorageLayout do
  use Fact.Seam.Adapter,
    registry: Fact.Seam.StorageLayout.Registry
    
  alias Fact.Context

  def records_path(%Context{database_path: root, storage_layout: layout}) do
    __seam_call__(layout, :records_path, [root])
  end

  def record_path(context, record_id) do
    Path.join(records_path(context), record_id)
  end

  def indices_path(%Context{database_path: root, storage_layout: layout}) do
    __seam_call__(layout, :indices_path, [root])
  end

  def ledger_path(%Context{database_path: root, storage_layout: layout}) do
    __seam_call__(layout, :ledger_path, [root])
  end
end
