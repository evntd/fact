defmodule Fact.IndexFileName do
  use Fact.Seam.Adapter,
    registry: Fact.Seam.FileName.Registry,
    allowed_impls: [
      {:raw, 1},
      {:hash, 1}
    ],
    default_impl: {:raw, 1}

  alias Fact.Context

  def for(%Context{index_file_name: instance}, record_id) do
    __seam_call__(instance, :for, [record_id])
  end
end
