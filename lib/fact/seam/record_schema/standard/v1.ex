defmodule Fact.Seam.RecordSchema.Standard.V1 do
  use Fact.Seam.RecordSchema,
    family: :standard,
    version: 1

  defstruct []

  @impl true
  def event_data(%__MODULE__{}, record), do: record["event_data"]

  @impl true
  def event_id(%__MODULE__{}, record), do: record["event_id"]

  @impl true
  def event_metadata(%__MODULE__{}, record), do: record["event_metadata"]

  @impl true
  def event_tags(%__MODULE__{}, record), do: record["event_tags"]

  @impl true
  def event_type(%__MODULE__{}, record), do: record["event_type"]

  @impl true
  def event_store_position(%__MODULE__{}, record), do: record["store_position"]

  @impl true
  def event_store_timestamp(%__MODULE__{}, record), do: record["store_timestamp"]

  @impl true
  def event_stream_id(%__MODULE__{}, record), do: record["stream_id"]

  @impl true
  def event_stream_position(%__MODULE__{}, record), do: record["stream_position"]
end
