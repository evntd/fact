defmodule Fact.Seam.EventSchema.Standard.V1 do
  @moduledoc """
  Standard `Fact.Seam.EventSchema` implementation. 

  Provides the default mapping of logical event attributes to the string keys
  used in event records. This schema defines the field names for all events
  in the standard event store.
  """
  use Fact.Seam.EventSchema,
    family: :standard,
    version: 1

  defstruct []

  @impl true
  def get(%__MODULE__{}, opts) when is_list(opts) do
    %{
      event_data: "event_data",
      event_id: "event_id",
      event_metadata: "event_metadata",
      event_tags: "event_tags",
      event_type: "event_type",
      event_store_position: "store_position",
      event_store_timestamp: "store_timestamp",
      event_stream_id: "stream_id",
      event_stream_position: "stream_position"
    }
  end
end
