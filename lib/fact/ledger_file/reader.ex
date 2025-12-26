defmodule Fact.LedgerFile.Reader do
  use Fact.Seam.FileReader.Adapter,
    context: :ledger_file_reader,
    allowed_impls: [{:fixed_size, 1}]
end
