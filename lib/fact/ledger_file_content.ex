defmodule Fact.LedgerFileContent do
  @allowed_formats [
    {:delimited, 1}
  ]
  @default_format {:delimited, 1}

  def allowed(), do: @allowed_formats
  def default(), do: @default_format

  def encode(
        %Fact.Context{ledger_file_content_format: %Fact.Seam.Instance{module: mod, struct: s}},
        record_ids
      ) do
    mod.encode(s, record_ids)
  end

  def decode(
        %Fact.Context{ledger_file_content_format: %Fact.Seam.Instance{module: mod, struct: s}},
        record_ids
      ) do
    mod.decode(s, record_ids)
  end
end
