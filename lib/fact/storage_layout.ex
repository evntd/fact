defmodule Fact.StorageLayout do
  use Fact.Seam.StorageLayout.Adapter

  def record_path(context, record_id) do
    Path.join(records_path(context), record_id)
  end
end