defmodule Fact.LedgerFileContent do
  use Fact.Seam.Adapter,
    registry: Fact.Seam.FileContent.Registry,
    allowed_impls: [{:delimited, 1}]

  alias Fact.Context

  def encode(%Context{index_file_content: instance}, record_ids) do
    __seam_call__(instance, :encode, [record_ids])
  end

  def decode(%Context{index_file_content: instance}, binary) do
    __seam_call__(instance, :decode, [binary])
  end
end
