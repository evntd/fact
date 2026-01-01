defmodule Fact.Seam.RecordSchema do
  use Fact.Seam

  @callback event_data(t(), Fact.Types.event_record(), opts :: keyword()) ::
              {:ok, Fact.Types.event_data()} | {:error, term()}
  @callback event_id(t(), Fact.Types.event_record(), opts :: keyword()) ::
              {:ok, Fact.Types.event_id()} | {:error, term()}
  @callback event_metadata(t(), Fact.Types.event_record(), opts :: keyword()) ::
              {:ok, Fact.Types.event_metadata()} | {:error, term()}
  @callback event_tags(t(), Fact.Types.event_record(), opts :: keyword()) ::
              {:ok, Fact.Types.event_tags()} | {:error, term()}
  @callback event_type(t(), Fact.Types.event_record(), opts :: keyword()) ::
              {:ok, Fact.Types.event_type()} | {:error, term()}
  @callback event_store_position(t(), Fact.Types.event_record(), opts :: keyword()) ::
              {:ok, Fact.Types.event_position()} | {:error, term()}
  @callback event_store_timestamp(t(), Fact.Types.event_record(), opts :: keyword()) ::
              {:ok, Fact.Types.event_timestamp()} | {:error, term()}
  @callback event_stream_id(t(), Fact.Types.event_record(), opts :: keyword()) ::
              {:ok, Fact.Types.event_stream_id()} | {:error, term()}
  @callback event_stream_position(t(), Fact.Types.event_record(), opts :: keyword()) ::
              {:ok, Fact.Types.event_position()} | {:error, term()}
end
