defmodule Fact.Types do
  @moduledoc """
  Defines the types which are used to within the package.
    
  > #### Warning {: .warning} 
  > 
  > Elixir's type system isn't as robust as say TypeScript or F#. So I've done my best to describe the types, their 
  > format, and encoding. Many of these are not enforced, and supplying other types may compile but produce errors or 
  > unexpected behavior. Here there be 🐉🐉.
    
  """

  @typedoc """
  The unique identifier for an event.
  """
  @type event_id :: lowercase_base16_uuid_v4_no_hyphens()

  @typedoc """
  Consumer defined map of data specific to the `t:Fact.Types.event_type/0`.
  """
  @type event_data :: map()

  @typedoc """
  Consumer defined map of metadata, specific to the system which produced the event.
  """
  @type event_metadata :: map()

  @typedoc """
  A number indicating the location of the event within the ledger or an event stream. 
  """
  @type event_position :: pos_integer()

  @typedoc """
  A consumer defined, domain specific id for an event stream, a logical partition within the ledger which is used to 
  relate events for downstream system capabilities. The default consistency boundary for persisting Domain-driven design
  Aggregate Roots.
  """
  @type event_stream :: non_whitespace_string()
  @type event_stream_id :: event_stream()

  @typedoc """
  A consumer defined, domain-specific metadata for an event, allowing for custom logical partitioning. Similar in
  concept to a `t:Fact.Types.event_stream/0`, however events may define many tags. These and `t:Fact.Types.event_type/0`
  are used to define `Fact.Query`s and provide the foundation for dynamic consistency boundaries.
  """
  @type event_tag :: non_whitespace_string()

  @type event_tags :: list(event_tag())

  @typedoc """
  The date and time when an `t:Fact.Types.event_record/0` was written to disk.
  """
  @type event_timestamp :: unix_microseconds()

  @typedoc """
  A consumer defined, domain-specific name for an event. 

  It is recommended they are named in the past-tense, and describe a fact that is important to capture for the domain. 
  """
  @type event_type :: non_whitespace_string()

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
          optional(:tags) => event_tags
        }

  @typedoc """
  An event_record is a map of a persisted event. All keys are strings **not atoms**. 
    
  > #### Info {: .info}
  > 
  > Elixir type definitions do not allow string values as map keys, but if it did, each event_record
  > would take the following shape:
  >   
  >     @type event_record :: %{
  >             required("event_data") => event_data(),
  >             required("event_id") => event_id(),
  >             required("event_metadata") => event_metadata(),
  >             required("event_tags") => list(event_tag()),
  >             required("event_type") => event_type(),
  >             required("store_position") => event_position(),
  >             required("store_timestamp") => event_timestamp(),
  >             optional("stream_id") => event_stream(),
  >             optional("stream_position") => event_position()
  >           }
    
  """
  @type event_record :: map()

  @typedoc """
  This is an opaque identifier that the system uses to access event records.
      
  When an instance uses the `id` filename scheme, this will be same as the `t:Fact.Types.event_id/0`, when the filename
  scheme is `cas` this will be an encoded result of a cryptographic hashing function. Don't use this for to support any
  kind of logic other than looking up `t:Fact.Types.event_record/0`.

  """
  @type record_id :: String.t()

  @typedoc """
  Defines the association between a `t:Fact.Types.record_id/0` and `t:Fact.Types.event_record/0`.
  This is primarily used by internally by Fact modules, and you most likely won't need to deal with directly.
  """
  @type record :: {record_id(), event_record()}

  @typedoc """
  The event sources which can be used in read operations.
  """
  @type read_event_source ::
          :all
          | :none
          | {:stream, Fact.Types.event_stream()}
          | {:index, Fact.EventIndexer.indexer_id(), Fact.EventIndexer.index_value()}
          | {:query,
             :all
             | :none
             | Fact.Query.t()
             | Fact.QueryItem.t()
             | nonempty_list(Fact.QueryItem.t())}

  @typedoc """
  Represents how many events are read from an event source.
  """
  @type read_count :: :all | non_neg_integer()

  @typedoc """
  Represents how the event source is traversed during a read.
    
    * `:forward`  - events are read with positions in increasing order (e.g. 1, 2, 3, ...)
    * `:backward` - events are read with positions in decreasing order (e.g. 100, 99, 98, ...)
  """
  @type read_direction :: :forward | :backward

  @typedoc """
  Represents where reading begins within the event source.
  """
  @type read_position :: :start | :end | non_neg_integer()

  @typedoc """
  Represents the element type that will be returned when a read stream is enumerated.
    
    * `event` - each element will be an `t:Fact.Types.event_record/0`
    * `record` - each element will be a `t:Fact.Types.record/0`
    * `record_id` - each element will be a `t:Fact.Types.record_id/0`
  """
  @type read_return_type :: :event | :record | :record_id

  @typedoc """
  The options that can be supplied to when reading from any `t:Fact.Types.read_event_source/0`.
  """
  @type read_options :: [
          direction: read_direction(),
          position: read_position(),
          count: read_count(),
          return_type: read_return_type()
        ]

  @typedoc """
  A UNIX timestamp with microsecond precision.
    
  The number of microseconds since January 1st, 1970 at 00:00 (UTC).
  """
  @type unix_microseconds() :: integer()

  @typedoc """
  A UUID v4 base16 (hexadecimal) encoded lowercase string without hyphens.
      
  (e.g. `9ff5f0c761ac49bb9a02f10f6f79e674`)
  """
  @type lowercase_base16_uuid_v4_no_hyphens :: String.t()

  @typedoc """
  A string that is not empty or solely consists of whitespace characters.
  """
  @type non_whitespace_string :: String.t()

  @typedoc """
  A string which 
  """
  @type opaque_string :: String.t()

  @doc """
  This macro injects module attributes into the calling module for consistent access to `t:event_record/0` map keys.

  > #### DO THIS {: .tip}
  >
  > Use these instead of strings when accessing event records.
  >  
  >     type = event[@event_type]
  >
  >     %{@event_type => type, @event_data => data, @event_tags => tags} = event
    
  > #### DON'T DO THIS {: .error}
  >
  > If or when the event schema changes, this will give you a headache.
  >
  >     type = event["event_type"] 
  >
  >     %{"event_type" => type, "event_data" => data, "event_tags" => tags} = event

  The following module attributes are defined:

    * `@event_data` - the data payload
    * `@event_id` — the unique event identifier
    * `@event_metadata` - the consumer defined metadata
    * `@event_store_position` - the global position within the event store
    * `@event_store_timestamp` - the timestamp when the event was created
    * `@event_stream` — the name of the event stream, this may be undefined
    * `@event_stream_position` — the position within the event stream, this may be undefined
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
