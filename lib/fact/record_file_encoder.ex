defmodule Fact.RecordFileEncoder do
  use Fact.Seam.Encoder.Adapter,
    context: :record_file_encoder,
    allowed_impls: [{:json, 1}]
end
