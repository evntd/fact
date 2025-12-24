defmodule Fact.RecordFileName do
  @allowed_formats [
    {:content_addressable, 1},
    {:event_id, 1}
  ]
  @default_format {:event_id, 1}

  def allowed(), do: @allowed_formats
  def default(), do: @default_format

  def for(
        %Fact.Context{record_file_name: %Fact.Seam.Instance{module: mod, struct: s}},
        event_record,
        encoded_record
      ) do
    mod.for(s, if(mod.id() === :content_addressable, do: encoded_record, else: event_record))
  end
end
