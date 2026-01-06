defmodule Fact.Seam.EventSchema.Standard.V1 do
  use Fact.Seam.EventSchema,
    family: :standard,
    version: 1

  defstruct []

  @impl true
  def event_data(%__MODULE__{}, opts) when is_list(opts), do: "event_data"
  
  @impl true
  def get_event_data(%__MODULE__{}, record, opts) when is_map(record) and is_list(opts),
    do: Map.get(record, "event_data")

  @impl true
  def set_event_data(%__MODULE__{}, record, value, opts) when is_map(record) and is_list(opts),
    do: Map.put(record, "event_data", value)

  @impl true
  def event_id(%__MODULE__{}, opts) when is_list(opts), do: "event_id"

  @impl true
  def get_event_id(%__MODULE__{}, record, _opts) when is_map(record),
    do: Map.get(record, "event_id")

  @impl true
  def set_event_id(%__MODULE__{}, record, value, opts) when is_map(record) and is_list(opts),
    do: Map.put(record, "event_id", value)

  @impl true
  def event_metadata(%__MODULE__{}, opts) when is_list(opts), do: "event_metadata"

  @impl true
  def get_event_metadata(%__MODULE__{}, record, _opts) when is_map(record),
    do: Map.get(record, "event_metadata")

  @impl true
  def set_event_metadata(%__MODULE__{}, record, value, opts)
      when is_map(record) and is_list(opts),
      do: Map.put(record, "event_metadata", value)

  @impl true
  def event_tags(%__MODULE__{}, opts) when is_list(opts), do: "event_tags"

  @impl true
  def get_event_tags(%__MODULE__{}, record, _opts) when is_map(record),
    do: Map.get(record, "event_tags")

  @impl true
  def set_event_tags(%__MODULE__{}, record, value, opts) when is_map(record) and is_list(opts),
    do: Map.put(record, "event_tags", value)

  @impl true
  def event_type(%__MODULE__{}, opts) when is_list(opts), do: "event_type"
    
  @impl true
  def get_event_type(%__MODULE__{}, record, _opts) when is_map(record),
    do: Map.get(record, "event_type")

  @impl true
  def set_event_type(%__MODULE__{}, record, value, opts) when is_map(record) and is_list(opts),
    do: Map.put(record, "event_type", value)

  @impl true
  def event_store_position(%__MODULE__{}, opts) when is_list(opts), do: "store_position"

  @impl true
  def get_event_store_position(%__MODULE__{}, record, _opts) when is_map(record),
    do: Map.get(record, "store_position")

  @impl true
  def set_event_store_position(%__MODULE__{}, record, value, opts)
      when is_map(record) and is_list(opts),
      do: Map.put(record, "store_position", value)

  @impl true
  def event_store_timestamp(%__MODULE__{}, opts) when is_list(opts), do: "store_timestamp"

  @impl true
  def get_event_store_timestamp(%__MODULE__{}, record, _opts) when is_map(record),
    do: Map.get(record, "store_timestamp")

  @impl true
  def set_event_store_timestamp(%__MODULE__{}, record, value, opts)
      when is_map(record) and is_list(opts),
      do: Map.put(record, "store_timestamp", value)

  @impl true
  def event_stream_id(%__MODULE__{}, opts) when is_list(opts), do: "stream_id"
      
  @impl true
  def get_event_stream_id(%__MODULE__{}, record, _opts) when is_map(record),
    do: Map.get(record, "stream_id")

  @impl true
  def set_event_stream_id(%__MODULE__{}, record, value, opts)
      when is_map(record) and is_list(opts),
      do: Map.put(record, "stream_id", value)

  @impl true
  def event_stream_position(%__MODULE__{}, opts) when is_list(opts), do: "stream_position"

  @impl true
  def get_event_stream_position(%__MODULE__{}, record, _opts) when is_map(record),
    do: Map.get(record, "stream_position")

  @impl true
  def set_event_stream_position(%__MODULE__{}, record, value, opts)
      when is_map(record) and is_list(opts),
      do: Map.put(record, "stream_position", value)
end
