defmodule Fact.IndexFileContent do
  @allowed_formats [
    {:delimited, 1}
  ]
  @default_format {:delimited, 1}

  def allowed(), do: @allowed_formats
  def default(), do: @default_format

  def encode(
        %Fact.Context{index_file_content_format: %Fact.Seam.Instance{module: mod, struct: s}},
        event_record
      ) do
    mod.encode(s, event_record)
  end

  def decode(
        %Fact.Context{index_file_content_format: %Fact.Seam.Instance{module: mod, struct: s}},
        event_record
      ) do
    mod.decode(s, event_record)
  end
end
