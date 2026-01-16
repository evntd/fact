defmodule Fact.Seam.EventSchema.Kurrent.V1 do
  @moduledoc false
  use Fact.Seam.EventSchema,
    family: :kurrent,
    version: 1

  defstruct []

  def get(%__MODULE__{}, opts) when is_list(opts) do
    %{
      event_data: "Data",
      event_id: "EventId",
      event_metadata: "Metadata",
      event_tags: "__Tags__",
      event_type: "EventType",
      event_store_position: "Position",
      event_store_timestamp: "Created",
      event_stream_id: "EventStreamId",
      event_stream_position: "EventNumber"
    }
  end
end
