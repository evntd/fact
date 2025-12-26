defmodule Fact.LedgerFileContent do
  use Fact.Seam.FileContent.Adapter,
    context: :ledger_file_content,
    registry: Fact.Seam.FileContent.Registry,
    allowed_impls: [{:delimited, 1}]
end
