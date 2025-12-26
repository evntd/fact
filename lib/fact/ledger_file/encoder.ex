defmodule Fact.LedgerFile.Encoder do
  use Fact.Seam.Encoder.Adapter,
    context: :ledger_file_encoder,
    allowed_impls: [{:delimited, 1}]
end
