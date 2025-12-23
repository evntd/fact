defmodule Fact.RecordFileContent do
  @allowed_formats [{:json, 1}]
  @default_format {:json, 1}

  def allowed(), do: @allowed_formats
  def default(), do: @default_format

  def encode(
        %Fact.Context{record_file_content_format: %Fact.Seam.Instance{module: mod, struct: s}},
        event_record
      ) do
    mod.encode(s, event_record)
  end

  def decode(
        %Fact.Context{record_file_content_format: %Fact.Seam.Instance{module: mod, struct: s}},
        event_record
      ) do
    mod.decode(s, event_record)
  end
end
