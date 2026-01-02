defmodule Fact.Seam.RecordSchema do
  use Fact.Seam
  use Fact.Types

  @callback get_event_data(t(), Types.event_record(), opts :: keyword()) ::
              Types.event_data() | {:error, term()}
  @callback set_event_data(
              t(),
              Types.event_record(),
              value :: Types.event_data(),
              opts :: keyword()
            ) ::
              Types.event_record() | {:error, term()}

  @callback get_event_id(t(), Types.event_record(), opts :: keyword()) ::
              Types.event_id() | {:error, term()}
  @callback set_event_id(
              t(),
              Types.event_record(),
              value :: Types.event_id(),
              opts :: keyword()
            ) ::
              Types.event_record() | {:error, term()}

  @callback get_event_metadata(t(), Types.event_record(), opts :: keyword()) ::
              Types.event_metadata() | {:error, term()}
  @callback set_event_metadata(
              t(),
              Types.event_record(),
              value :: Types.event_metadata(),
              opts :: keyword()
            ) ::
              Types.event_record() | {:error, term()}

  @callback get_event_tags(t(), Types.event_record(), opts :: keyword()) ::
              Types.event_tags() | {:error, term()}
  @callback set_event_tags(
              t(),
              Types.event_record(),
              value :: Types.event_tags(),
              opts :: keyword()
            ) ::
              Types.event_record() | {:error, term()}

  @callback get_event_type(t(), Types.event_record(), opts :: keyword()) ::
              Types.event_type() | {:error, term()}
  @callback set_event_type(
              t(),
              Types.event_record(),
              value :: Types.event_type(),
              opts :: keyword()
            ) ::
              Types.event_record() | {:error, term()}

  @callback get_event_store_position(t(), Types.event_record(), opts :: keyword()) ::
              Types.event_position() | {:error, term()}
  @callback set_event_store_position(
              t(),
              Types.event_record(),
              value :: Types.event_position(),
              opts :: keyword()
            ) ::
              Types.event_record() | {:error, term()}

  @callback get_event_store_timestamp(t(), Types.event_record(), opts :: keyword()) ::
              Types.event_timestamp() | {:error, term()}
  @callback set_event_store_timestamp(
              t(),
              Types.event_record(),
              value :: Types.event_timestamp(),
              opts :: keyword()
            ) ::
              Types.event_record() | {:error, term()}

  @callback get_event_stream_id(t(), Types.event_record(), opts :: keyword()) ::
              Types.event_stream_id() | {:error, term()}
  @callback set_event_stream_id(
              t(),
              Types.event_record(),
              value :: Types.event_stream_id(),
              opts :: keyword()
            ) ::
              Types.event_record() | {:error, term()}

  @callback get_event_stream_position(t(), Types.event_record(), opts :: keyword()) ::
              Types.event_position() | {:error, term()}
  @callback set_event_stream_position(
              t(),
              Types.event_record(),
              value :: Types.event_position(),
              opts :: keyword()
            ) ::
              Types.event_record() | {:error, term()}
end
