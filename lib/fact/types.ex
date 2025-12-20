defmodule Fact.Types do
  @moduledoc """
  Provides a set of common event field keys for use across modules in the
  `Fact` system.

  When `use Fact.Types` is invoked inside another module, it injects
  a series of module attributes representing canonical keys used when
  working with events - including their identifiers, metadata, payload,
  and stream position information.

  This helps maintain consistency across the codebase and avoids
  scattering string literals throughout the system.
  """

  @typedoc """
  A handle to a Fact database instance.
  """
  @type instance_name :: atom()

  @type unix_timestamp_microseconds() :: integer()

  @type event_id :: String.t()
  @type event_data :: map()
  @type event_metadata :: map()
  @type event_position :: non_neg_integer()
  @type event_stream :: String.t()
  @type event_tag :: String.t()
  @type event_type :: String.t()

  @typedoc """
  An event is a map with at least a `:type` key.
    
  It may also include:
    * `:id` - a UUID string
    * `:data` - a map of custom data
    * `:metadata` - a map of custom data about the data
    * `:tags` - a list of custom identifiers to aid in defining context boundaries
  """
  @type event :: %{
          required(:type) => event_type,
          optional(:id) => event_id,
          optional(:data) => event_data,
          optional(:metadata) => event_metadata,
          optional(:tags) => list(event_tag)
        }

  @type event_record :: map()

  #  @type event_record :: %{
  #          required("event_data") => event_data(),
  #          required("event_id") => event_id(),
  #          required("event_metadata") => event_metadata(),
  #          required("event_tags") => list(event_tag()),
  #          required("event_type") => event_type(),
  #          required("store_position") => event_position(),
  #          required("store_timestamp") => unix_timestamp_microseconds(),
  #          optional("stream_id") => event_stream(),
  #          optional("stream_position") => event_position()
  #        }

  @type record_id :: String.t()

  @type index() :: String.t()
  @type indexer_module() ::
          {Fact.EventDataIndexer, String.t()}
          | Fact.EventStreamCategoryIndexer
          | Fact.EventStreamIndexer
          | Fact.EventStreamsByCategoryIndexer
          | Fact.EventStreamsIndexer
          | Fact.EventTagsIndexer
          | Fact.EventTypeIndexer

  @type event_source ::
          :all
          | :none
          | {:stream, Fact.Types.event_stream()}
          | {:index, Fact.Types.indexer_module(), Fact.Types.index()}
          | {:query, Fact.Query.t() | Fact.QueryItem.t() | nonempty_list(Fact.QueryItem.t())}

  @type read_count :: :all | non_neg_integer()
  @type read_direction :: :forward | :backward
  @type read_position :: :start | :end | non_neg_integer()
  @type read_return_type :: :event | :record | :record_id
  @type read_opts :: [
          direction: read_direction(),
          position: read_position(),
          count: read_count(),
          return_type: read_return_type()
        ]

  @doc """
  Injects module attributes into the calling module for consistent access to event record keys.

  > #### DO THIS {: .tip}
  >
  > Use these instead of strings when accessing event records.
  >  
  >     type = event[@event_type]
    
  > #### DON'T DO THIS {: .error}
  >
  > If or when the event schema changes, this will give you a headache.
  >
  >     type = event["event_type"] 


  The following module attributes are defined:

    * `@event_data` - the data payload
    * `@event_id` — the unique event identifier
    * `@event_metadata` - the consumer defined metadata
    * `@event_store_position` - the global position within the event store
    * `@event_store_timestamp` - the timestamp when the event was created
    * `@event_stream` — the name of the event stream, this may be undefined within the event record
    * `@event_stream_position` — the position within the event stream, this may be undefined within the event record
    * `@event_tags` — the list of tags associated with the event
    * `@event_type` — the type of the event

  """
  defmacro __using__(_opts) do
    quote do
      @event_data "event_data"
      @event_id "event_id"
      @event_metadata "event_metadata"
      @event_store_position "store_position"
      @event_store_timestamp "store_timestamp"
      @event_stream "stream_id"
      @event_stream_position "stream_position"
      @event_tags "event_tags"
      @event_type "event_type"
    end
  end
end
