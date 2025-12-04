defmodule Fact.EventKeys do
  @moduledoc """
  Provides a set of common event field keys for use across modules in the
  `Fact` system.

  When `use Fact.EventKeys` is invoked inside another module, it injects
  a series of module attributes representing canonical keys used when
  working with events — including their identifiers, metadata, payload,
  and stream position information.

  This helps maintain consistency across the codebase and avoids
  scattering string literals throughout the system.
  """

  @doc """
  Injects common event key attributes into the calling module.

  The following module attributes are defined:

    * `@event_data` — the event payload key (`"data"`)
    * `@event_id` — the event identifier key (`"id"`)
    * `@event_metadata` — metadata associated with the event (`"metadata"`)
    * `@event_store_position` — global event store position (`"pos"`)
    * `@event_store_timestamp` — event timestamp (`"ts"`)
    * `@event_stream` — the name of the event stream (`"stream"`)
    * `@event_stream_position` — the event's position within the stream (`"stream_position"`)
    * `@event_tags` — tags associated with the event (`"tags"`)
    * `@event_type` — the event type key (`"type"`)

  These attributes are intended to provide consistent field names when
  encoding, decoding, or manipulating events.
  """
  defmacro __using__(_opts) do
    quote do
      @event_data "data"
      @event_id "id"
      @event_metadata "metadata"
      @event_store_position "pos"
      @event_store_timestamp "ts"
      @event_stream "stream"
      @event_stream_position "stream_position"
      @event_tags "tags"
      @event_type "type"
    end
  end
end
