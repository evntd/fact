defmodule Fact.Seam.EventSchema.Kurrent.V1 do
  @moduledoc false
  use Fact.Seam.EventSchema,
    family: :kurrent,
    version: 1

  import Fact.Seam.Parsers, only: [parse_field_name: 1]

  @default_event_tags "__Tags__"

  @enforce_keys [:event_tags]
  defstruct [:event_tags]

  @impl true
  def default_options(), do: %{event_tags: @default_event_tags}

  @impl true
  def option_specs() do
    %{
      event_tags: %{
        allowed: :any,
        parse: &parse_field_name/1,
        error: :invalid_event_tags
      }
    }
  end

  @impl true
  def get(%__MODULE__{event_tags: event_tags}, opts) when is_list(opts) do
    %{
      event_data: "Data",
      event_id: "EventId",
      event_metadata: "Metadata",
      event_tags: event_tags,
      event_type: "EventType",
      event_store_position: "Position",
      event_store_timestamp: "Created",
      event_stream_id: "EventStreamId",
      event_stream_position: "EventNumber"
    }
  end
end
