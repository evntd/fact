defmodule Fact.RecordSchema do
  alias Fact.Context
  alias Fact.Seam.Instance
  alias Fact.Seam.RecordSchema.Registry

  def allowed_impls(), do: [{:standard, 1}]
  def default_impl(), do: {:standard, 1}
  def default_impl_options(), do: %{}
  def impl_registry(), do: Registry

  def event_data(%Context{record_schema: %Instance{module: mod, struct: s}}, record) do
    mod.event_data(s, record)
  end

  def event_id(%Context{record_schema: %Instance{module: mod, struct: s}}, record) do
    mod.event_id(s, record)
  end

  def event_metadata(%Context{record_schema: %Instance{module: mod, struct: s}}, record) do
    mod.event_metadata(s, record)
  end

  def event_tags(%Context{record_schema: %Instance{module: mod, struct: s}}, record) do
    mod.event_tags(s, record)
  end

  def event_type(%Context{record_schema: %Instance{module: mod, struct: s}}, record) do
    mod.event_type(s, record)
  end

  def event_store_position(%Context{record_schema: %Instance{module: mod, struct: s}}, record) do
    mod.event_store_position(s, record)
  end

  def event_store_timestamp(%Context{record_schema: %Instance{module: mod, struct: s}}, record) do
    mod.event_store_timestamp(s, record)
  end

  def event_stream_id(%Context{record_schema: %Instance{module: mod, struct: s}}, record) do
    mod.event_stream_id(s, record)
  end

  def event_stream_position(%Context{record_schema: %Instance{module: mod, struct: s}}, record) do
    mod.event_stream_position(s, record)
  end
end
