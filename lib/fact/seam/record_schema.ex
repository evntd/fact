defmodule Fact.Seam.RecordSchema do
  use Fact.Seam

  @callback event_data(t(), record :: Fact.Types.event_record()) ::
              Fact.Types.event_data()
  @callback event_id(t(), record :: Fact.Types.event_record()) :: Fact.Types.event_id()
  @callback event_metadata(t(), record :: Fact.Types.event_record()) ::
              Fact.Types.event_metadata()
  @callback event_tags(t(), record :: Fact.Types.event_record()) ::
              Fact.Types.event_tags()
  @callback event_type(t(), record :: Fact.Types.event_record()) ::
              Fact.Types.event_type()
  @callback event_store_position(t(), record :: Fact.Types.event_record()) ::
              Fact.Types.event_position()
  @callback event_store_timestamp(t(), record :: Fact.Types.event_record()) ::
              Fact.Types.event_timestamp()
  @callback event_stream_id(t(), record :: Fact.Types.event_record()) ::
              Fact.Types.event_stream_id()
  @callback event_stream_position(t(), record :: Fact.Types.event_record()) ::
              Fact.Types.event_position()
end
