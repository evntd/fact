defmodule Fact.IndexFileContent do
  alias Fact.Context
  alias Fact.Seam.Instance
  alias Fact.Seam.FileContent.Registry

  @allowed_impls [
    {:delimited, 1}
  ]
  @default_impl {:delimited, 1}

  def allowed_impls(), do: @allowed_impls
  def default_impl(), do: @default_impl
  def impl_registry(), do: Registry

  def encode(
        %Context{index_file_content: %Instance{module: mod, struct: s}},
        event_record
      ) do
    mod.encode(s, event_record)
  end

  def decode(
        %Context{index_file_content: %Instance{module: mod, struct: s}},
        event_record
      ) do
    mod.decode(s, event_record)
  end
end
