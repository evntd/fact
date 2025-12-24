defmodule Fact.RecordFileName do
  use Fact.Seam.Adapter,
    registry: Fact.Seam.FileName.Registry,
    allowed_impls: [
      {:content_addressable, 1},
      {:event_id, 1}
    ],
    default_impl: {:event_id, 1}
    
  alias Fact.Context
  alias Fact.Seam.Instance

  def for(%Context{record_file_name: %Instance{module: mod} = instance}, event_record, encoded_record) do
    __seam_call__(instance, :for, [if(mod.id() == :content_addressable, do: encoded_record, else: event_record)])
  end
end
