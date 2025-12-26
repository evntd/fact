defmodule Fact.LedgerFile.Decoder do
  use Fact.Seam.Decoder.Adapter,
    context: :ledger_file_decoder,
    allowed_impls: [{:raw, 1}]
end
