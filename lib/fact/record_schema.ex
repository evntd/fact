defmodule Fact.RecordSchema do
  use Fact.Seam

  @callback event_data(format :: t(), record :: Fact.Types.event_record()) ::
              Fact.Types.event_data()
  @callback event_id(format :: t(), record :: Fact.Types.event_record()) :: Fact.Types.event_id()
  @callback event_metadata(format :: t(), record :: Fact.Types.event_record()) ::
              Fact.Types.event_metadata()
  @callback event_tags(format :: t(), record :: Fact.Types.event_record()) ::
              Fact.Types.event_tags()
  @callback event_type(format :: t(), record :: Fact.Types.event_record()) ::
              Fact.Types.event_type()
  @callback event_store_position(format :: t(), record :: Fact.Types.event_record()) ::
              Fact.Types.event_position()
  @callback event_store_timestamp(format :: t(), record :: Fact.Types.event_record()) ::
              Fact.Types.event_timestamp()
  @callback event_stream_id(format :: t(), record :: Fact.Types.event_record()) ::
              Fact.Types.event_stream_id()
  @callback event_stream_position(format :: t(), record :: Fact.Types.event_record()) ::
              Fact.Types.event_position()
end
