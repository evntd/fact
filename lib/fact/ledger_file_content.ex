defmodule Fact.LedgerFileContent do
  alias Fact.Context
  alias Fact.Seam.Instance
  alias Fact.Seam.FileContent.Registry

  def allowed_impls(), do: [{:delimited, 1}]
  def default_impl(), do: {:delimited, 1}
  def impl_registry(), do: Registry

  def encode(%Context{ledger_file_content: %Instance{module: mod, struct: s}}, record_ids) do
    mod.encode(s, record_ids)
  end

  def decode(%Context{ledger_file_content: %Instance{module: mod, struct: s}}, record_ids) do
    mod.decode(s, record_ids)
  end
end
