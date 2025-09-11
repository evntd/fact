defmodule Fact.EventKeys do
  defmacro __using__(_opts) do
    quote do      
      @event_data "data"
      @event_id "id"
      @event_metadata "metadata"
      @event_stream "stream"
      @event_stream_position "stream_position"
      @event_type "type"
      @query_position "query_position"
      @store_position "pos"
      @store_timestamp "ts"
    end
  end
end