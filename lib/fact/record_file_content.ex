defmodule Fact.RecordFileContent do
  alias Fact.Context
  alias Fact.Seam.Instance
  alias Fact.Seam.FileContent.Registry

  def allowed_impls(), do: [{:json, 1}]
  def default_impl(), do: {:json, 1}
  def impl_registry(), do: Registry

  def encode(%Context{record_file_content: %Instance{module: mod, struct: s}}, event_record) do
    mod.encode(s, event_record)
  end

  def decode(%Context{record_file_content: %Instance{module: mod, struct: s}}, event_record) do
    mod.decode(s, event_record)
  end
end
