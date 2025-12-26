defmodule Fact.RecordFile.Name do
  use Fact.Seam.FileName.Adapter,
    context: :record_file_name,
    required_capabilities: [:fixed_size],
    default_impl: {:event_id, 1}

  alias Fact.Context
  alias Fact.Seam.Instance

  def get(
        %Context{record_file_name: %Instance{module: mod}} = context,
        event_record,
        encoded_record
      ) do
    if :content_addressable == mod.id() do
      get(context, encoded_record)
    else
      get(context, event_record)
    end
  end

  def size(%Context{record_file_name: instance}) do
    __seam_call__(instance, :size, [])
  end
end
