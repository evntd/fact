defmodule Fact.RecordFile.Decoder do
  use Fact.Seam.Decoder.Adapter,
    context: :record_file_decoder,
    allowed_impls: [{:json, 1}]
end
