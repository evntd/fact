defmodule Fact.RecordSchema do
  use Fact.Seam.Adapter,
    registry: Fact.Seam.RecordSchema.Registry

  alias Fact.Context

  def event_data(%Context{record_schema: schema}, record) do
    __seam_call__(schema, :event_data, [record])
  end

  def event_id(%Context{record_schema: schema}, record) do
    __seam_call__(schema, :event_id, [record])
  end

  def event_metadata(%Context{record_schema: schema}, record) do
    __seam_call__(schema, :event_metadata, [record])
  end

  def event_tags(%Context{record_schema: schema}, record) do
    __seam_call__(schema, :event_tags, [record])
  end

  def event_type(%Context{record_schema: schema}, record) do
    __seam_call__(schema, :event_type, [record])
  end

  def event_store_position(%Context{record_schema: schema}, record) do
    __seam_call__(schema, :event_store_position, [record])
  end

  def event_store_timestamp(%Context{record_schema: schema}, record) do
    __seam_call__(schema, :event_store_timestamp, [record])
  end

  def event_stream_id(%Context{record_schema: schema}, record) do
    __seam_call__(schema, :event_stream_id, [record])
  end

  def event_stream_position(%Context{record_schema: schema}, record) do
    __seam_call__(schema, :event_stream_position, [record])
  end
end
