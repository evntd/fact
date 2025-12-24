defmodule Fact.RecordFileContent do
  use Fact.Seam.Adapter,
    registry: Fact.Seam.FileContent.Registry,
    allowed_impls: [{:json, 1}]

  alias Fact.Context

  def encode(%Context{record_file_content: instance}, event_record) do
    __seam_call__(instance, :encode, [event_record])
  end

  def decode(%Context{record_file_content: instance}, binary) do
    __seam_call__(instance, :decode, [binary])
  end
end
