defmodule Fact.EventKeys do
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
