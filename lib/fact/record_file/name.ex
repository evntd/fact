defmodule Fact.RecordFile.Name do
  use Fact.Seam.FileName.Adapter,
    context: :record_file_name,
    allowed_impls: [{:hash, 1}, {:event_id, 1}],
    default_impl: {:event_id, 1}

  alias Fact.Context
  alias Fact.Seam.Instance

  def get(
        %Context{record_file_name: %Instance{module: mod}} = context,
        {event_record, encoded_record} = value
      )
      when is_tuple(value) do
    if :hash == mod.family() do
      get(context, encoded_record, [])
    else
      get(context, event_record, [])
    end
  end
end
