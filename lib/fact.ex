defmodule Fact do
  @moduledoc """
  Fact is an event sourcing database, an event store.
  """

  @typedoc """
  A unique identifier for a Fact database.
    
  It is used as the primary handle for all database operations. Many 
  Fact subsystems use this identifier to retrieve the database context 
  in order to perform file and storage operations.
  """
  @type database_id :: uuid_v4_base32_uppercase_sans_padding()

  @typedoc """
  Represents an event before being written to the event store.

  At minimum, it must define a `:type` key.  
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
  Consumer defined map of data specific to the `t:Fact.event_type/0`.
  """
  @type event_data :: map()

  @typedoc """
  The unique identifier for an event.
  The actual value depends on the configuration of `Fact.Event.Id`.
  """
  @type event_id :: opaque_string()

  @typedoc """
  Consumer defined map of metadata, specific to the system which produced the event.
  """
  @type event_metadata :: map()

  @typedoc """
  A number indicating the location of the event within the ledger or an event stream. 
  """
  @type event_position :: pos_integer()

  @typedoc """
  A map containing all the event details.
  """
  @type event_record :: map()

  @typedoc """
  A schema definition describing the field names used in a `t:Fact.event/0`.
    
  Each key in this map represents a logical event attribute, and its value is the
  string key under which that attribute is stored in the event map.
  """
  @type event_record_schema :: %{
          required(:event_data) => String.t(),
          required(:event_id) => String.t(),
          required(:event_metadata) => String.t(),
          required(:event_tags) => String.t(),
          required(:event_type) => String.t(),
          required(:event_store_position) => String.t(),
          required(:event_store_timestamp) => String.t(),
          required(:event_stream_id) => String.t(),
          required(:event_stream_position) => String.t()
        }

  @typedoc """
  A consumer defined, domain specific id for a stream of events.

  An event stream represents a logical partition within the ledger which
  is used to relate events for downstream system capabilities. The default 
  consistency boundary for persisting Domain-Driven Design (DDD) Aggregate Roots.
  """
  @type event_stream_id :: no_whitespace_string()

  @typedoc """
  A consumer defined, domain-specific metadata for an event, allowing for custom logical partitioning. Similar in
  concept to a `t:Fact.event_stream_id/0`, however events may define many tags. These and `t:Fact.event_type/0`
  are used to define `Fact.Query`s and provide the foundation for dynamic consistency boundaries.
  """
  @type event_tag :: no_whitespace_string()

  @type event_tags :: list(event_tag())

  @typedoc """
  A consumer defined, domain-specific name for an event. 

  It is recommended they are named in the past-tense, and describe a fact that is important to capture for the domain. 
  """
  @type event_type :: no_whitespace_string()

  @typedoc """
  A string that contains no whitespace characters of any kind, including 
  spaces, tabs, newlines, and non-displayable control characters.
  """
  @type no_whitespace_string :: String.t()

  @typedoc """
  A string whose internal structure is opaque to consumers.
    
  Opaque strings should be treated as identifiers or tokens whose format 
  is not meaningful outside the system. Do not make assumptions about their
  contents or structure.
  """
  @type opaque_string :: String.t()

  @typedoc """
  Specifies the maximum number of items to return from a read operation.
  """
  @type read_count_option :: :all | non_neg_integer()

  @typedoc """
  Specifies the direction in which events are read from an event source.
  """
  @type read_direction_option :: :forward | :backward

  @typedoc """
  The position at which a read operation begins.
  """
  @type read_position_option :: :start | :end | non_neg_integer()

  @typedoc """
  Options for customizing a read operation from an event source.
  """
  @type read_option ::
          {:count, read_count_option()}
          | {:direction, read_direction_option()}
          | {:eager, boolean()}
          | {:position, read_position_option()}
          | {:result, read_result_option()}

  @typedoc """
  A keyword list of options customizing a read operation.

  Each option is a `read_option()`. Defaults are applied for any options not specified.
  """
  @type read_options :: list(read_option())

  @typedoc """
  Represents the possible values when reading events from a query source.
  """
  @type read_query_source ::
          :all
          | :none
          | Fact.Query.t()
          | Fact.QueryItem.t()
          | [Fact.QueryItem.t()]

  @typedoc """
  An enumerable collection (`List` or `Stream`) containing the values returned by the read operation.
  """
  @type read_result ::
          Enumerable.t(event_record())
          | Enumerable.t(record())
          | Enumerable.t(record_id())

  @typedoc """
  Specifies the element type returned by the read operation.
  """
  @type read_result_option :: :event | :record | :record_id

  @typedoc """
  Represents the source from which events are read.
  """
  @type read_source ::
          :none
          | :all
          | {:stream, event_stream_id()}
          | {:index, Fact.EventIndexer.indexer_id(), Fact.EventIndexer.index_value()}
          | {:query, read_query_source()}

  @typedoc """
  A persisted event paired with its unique identifier.
  """
  @type record :: {record_id(), event_record()}

  @typedoc """
  An opaque string that uniquely identifies a persisted event.

  The actual value and format depend on the configured `Fact.RecordFile.Name`.
  """
  @type record_id :: opaque_string()

  @type subscribe_option ::
          {:subscriber, pid()}
          | {:position, read_position_option()}

  @type subscribe_options :: list(subscribe_option)

  @typedoc """
  Represents the event sources that a process may subscribe to for notifications. 
  """
  @type subscribe_source ::
          :all
          | {:stream, event_stream_id()}
          | {:index, Fact.EventIndexer.indexer_id(), Fact.EventIndexer.index_value()}
          | {:query, Fact.QueryItem.t() | [Fact.QueryItem.t()]}

  @typedoc """
  An RFC-4122 UUID v4 encoded in Base32, using only uppercase characters. 
  The encoding contains no padding characters (`=`). This defines the 
  expected format; it does not perform validation at runtime.
  """
  @type uuid_v4_base32_uppercase_sans_padding :: String.t()

  def open(path) do
    {:ok, _pid} =
      case Process.whereis(Fact.Supervisor) do
        nil ->
          Fact.Supervisor.start_link([])

        pid ->
          {:ok, pid}
      end

    Fact.Supervisor.start_database(path)
  end

  @spec append(
          Fact.database_id(),
          Fact.event() | [Fact.event(), ...],
          Fact.Query.t(),
          Fact.event_position(),
          keyword()
        ) :: {:ok, Fact.event_position()} | {:error, term()}
  def append(
        database_id,
        events,
        fail_if_match \\ nil,
        after_position \\ 0,
        opts \\ []
      ) do
    Fact.EventLedger.commit(database_id, events, fail_if_match, after_position, opts)
  end

  @doc """
  Appends one or more events to a stream. This enriches the appended event records with 
  `stream_id` and `stream_position`.

  * `events` is a single event or list of events. 
  * `event_stream` is a string that uniquely identifies stream.
  * `event_position` is a non-negative integer which is used to ensure you can only append 
    to the stream if it is at the exact `stream_position`. 

    You may also provide one of the following values for different behavior.
      * `:any` - No check is made, any  
      * `:none` - Ensures the stream does not exist, this is the first append. Same as expected_position = 0.
      * `:exists` - Ensures the stream already exists, equivalent to expected_position >= 1.

  ## Examples
    
  Append a single event.
    
      iex> {:ok, db} = Fact.open("data/turtle")
      {:ok, "TURTLE4F7Q6Y2X3VQKBJ5M7P4Z"}
    
      iex> Fact.append_stream(db, %{type: "egg_hatched", data: %{name: "Turts"}}, "turtle-1")
      {:ok, 1}
    
      iex> Fact.read(db, {:stream, "turtle-1"}) |> Enum.to_list()
      [
        %{
          "event_data" => %{"name" => "Turts"},
          "event_id" => "3bb4808303c847fd9ceb0a1251ef95da",                                                                                                                                                                                                                                                               
          "event_metadata" => %{},                                                                                                                                                                                                                                                                                        
          "event_tags" => [],                                                                                                                                                                                                                                                                                             
          "event_type" => "egg_hatched",                                                                                                                                                                                                                                                                                  
          "store_position" => 2,                                                                                                                                                                                                                                                                                          
          "store_timestamp" => 1765039106962264,                                                                                                                                                                                                                                                                          
          "stream_id" => "turtle-1",                                                                                                                                                                                                                                                                                  
          "stream_position" => 1                                                                                                                                                                                                                                                                                          
        }                                                                                                                                                                                                                                                                                                                 
      ]  

  Append another event, expecting correct stream position.
    
      iex> Fact.append_stream(:mydb, %{type: "MySecondEvent"}, "myteststream", 1)
      {:ok, 2}
    
  Append a third event, supplying an incorrect stream position.
    
      iex> Fact.append_stream(:mydb, %{type: "MyThirdEvent"}, "myteststream", 1)
      {:error, %Fact.ConcurrencyError{source: "myteststream", actual: 2, expected: 1}}

  """
  @spec append_stream(
          Fact.database_id(),
          Fact.event() | [Fact.event(), ...],
          Fact.event_stream_id(),
          Fact.event_position() | :any | :none | :exists,
          keyword()
        ) :: {:ok, Fact.event_position()} | {:error, term()}
  def append_stream(
        database_id,
        events,
        event_stream,
        expected_position \\ :any,
        opts \\ []
      ) do
    Fact.EventStreamWriter.commit(database_id, events, event_stream, expected_position, opts)
  end

  @doc """
  Read from an event source.

  ## Event Sources

  Like most event stores, you can read from the global stream, or an individual event stream. 
  Fact provides a few more options...

    * `:none` - the empty stream  

    * `:all` - the all stream (a.k.a. the global stream; a.k.a. the ledger)

    * `{:stream, stream_id}` - an individual event stream

    * `{:index, indexer_id, index}` - an event index 

    * `{:query, query_items}` - an event query

  ## Options
    
  You may provide a keyword list with the following options to craft the results to fit your need.
  If any of the options are not specified, sensible defaults will be provided.
    
  ### direction:
    
    * `:forward` **(default)** - events are read in increasing position order (e.g. 1, 2, 3, ...)
    * `:backward` - events are read in decreasing position order (e.g. 100, 99, 98, ...)

  > #### Note {: .info}
  >
  > Positions will not always increase or decrease by 1, it totally depends on the event source.

  ### position:
    
  Set the position to begin reading the event source.

    * `:start` **(default)** - the position immediately **before the first item** in the event source
    * `:end` - the position immediately **after the last item** in the event source
    * Or a non-negative integer representing the absolute position within the source

  > #### A note on specific positions {: .info}
  >
  > The meaning of the integer position is specific to the event source.
  > 
  >   * For streams, it refers to the stream position.
  >   * Other event sources store position (i.e. the global stream position)

  > #### A reminder when reading from the end {: .tip}
  >
  > Starting reads from the end is typically only used when **reading backwards**, or subscribing to a live source. 
  > So if you're unexpectedly getting no results, double-check your direction and position options.
  >
  > I've made these mistake many a time...🤦
  >   
  >   * reading forward from the end
  >   * reading backward from the start 

  ### count:
    
  Control the maximum size of the result set.
    
    * `:all` **(default)** - reads everything in the event source
    * Or a non-negative integer. 

  > #### You've been warned 🤠 🧑‍🚒 {: .warning}
  >
  > This option is super useful if you don't want to return a bazillion events to a consumer,
  > spiking I/O ops, slowing response times, and generally clogging up the pipes. 
  > 
  > But this is one area where the default value will happily allow you to shoot yourself in the foot.

  ### result:
    
  Control the shape of the elements in result set.
        
    * `:event` **(default)** - each element is a map containing the event details. 
    * `:record` - each element is a 2-tuple `{record_id, event}` containing both the record id and the event.
    * `:record_id` - each element is the record id of the event.

  > #### Event schemas are ...kind of... configurable {: .info}  
  > 
  > When using `:event` or `record`, the exact "shape" of the event depends on the configured schema.
  >
  > See the `Fact.Seam.EventSchema.Registry` for all the available schemas.

  > #### What's a record id??? {: .info}
  >
  > Fact separates the concepts of an **event id** and a **record id**. The record id is the actual 
  > name of file on disk where the event is stored. This could be the same as the event id, and by 
  > default it is... but it really depends on how the `Fact.RecordFile.Name` has been configured.

  ### eager:

  Controls if the result set will be enumerated or lazy.
    
    * `true` **(default)** - The internal `Stream` is enumerated and a `List` is returned.
    * `false` - The result is returned as `Stream`

  > #### Fool me once, shame on, shame on you. Fool me ... you can't get fooled again {: .warning} 
  >  
  > If the event source being read has many events, and `:count` is `:all`, it would be
  > quite wise 🧙‍♂️ to set this to **false**.  Nearly all the internal components of Fact 
  > use lazy reads, this is really just meant as a convenience so you don't have to 
  > remember to `|> Enum.to_list()`.
  """
  @spec read(database_id(), read_source(), read_options()) :: read_result()
  def read(database_id, event_source, options \\ [])

  def read(database_id, :none, options) when is_binary(database_id) and is_list(options) do
    Stream.concat([])
  end

  def read(database_id, :all, options) when is_binary(database_id) and is_list(options) do
    Fact.Database.read_ledger(database_id, Keyword.put_new(options, :eager, true))
  end

  def read(database_id, {:stream, event_stream}, options)
      when is_binary(database_id) and is_binary(event_stream) and is_list(options) do
    read(database_id, {:index, {Fact.EventStreamIndexer, nil}, event_stream}, options)
  end

  def read(database_id, {:query, :all}, options)
      when is_binary(database_id) and is_list(options) do
    read(database_id, :all, options)
  end

  def read(database_id, {:query, :none}, options)
      when is_binary(database_id) and is_list(options) do
    read(database_id, :none, options)
  end

  def read(database_id, {:query, %Fact.QueryItem{} = query}, options)
      when is_binary(database_id) and is_list(options) do
    read(database_id, {:query, Fact.QueryItem.to_function(query)}, options)
  end

  def read(database_id, {:query, [%Fact.QueryItem{} | _] = query_items}, options)
      when is_binary(database_id) and is_list(query_items) and is_list(options) do
    read(database_id, {:query, Fact.QueryItem.to_function(query_items)}, options)
  end

  def read(database_id, {:query, query_fun}, options)
      when is_binary(database_id) and is_function(query_fun) and is_list(options) do
    Fact.Database.read_query(database_id, query_fun, Keyword.put_new(options, :eager, true))
  end

  def read(database_id, {:index, indexer_id, index}, options)
      when is_binary(database_id) and is_tuple(indexer_id) and tuple_size(indexer_id) == 2 and
             is_binary(index) and
             is_list(options) do
    Fact.Database.read_index(
      database_id,
      indexer_id,
      index,
      Keyword.put_new(options, :eager, true)
    )
  end

  @doc """
  Subscribe a process to an event source.
    
  A subscription streams new events to the subscriber process as they are appended to the event store.
  The subscriber process receives one message per event in the form:
    
    * `{:record, record}` - where record is a 2-tuple `{record_id, event_record}` (see `t:Fact.record()`)

  The subscription begins by replaying events from the specified source, starting at the configured position.
  Once all historical events have been delivered, the processes receives a `:caught_up` message and the subscription
  shifts into **live mode**, where it waits for and delivers new events as they arrive.
    
  ## Event Sources

  Subscriptions support most of the same sources as `read/3`, with a few exceptions. 

  Subscribing to the empty stream (i.e. `:none`) would create a very lonely `Fact.CatchUpSubscription` process
  that never delivers any messages, and I don't believe that would be useful. If you have a legitimate use case,
  please make your case. It would be straightforward to implement and support.

  Subscribing to query sources requires `t:Fact.QueryItem.t/0`; a `t:Fact.Query.t/0` won't work here. 
  A `t:Fact.Query.t/0` is just a function, and that function depends on data produced by a combination 
  of the `Fact.EventTypeIndexer`, `Fact.EventTagsIndexer`, and any number of `Fact.EventDataIndexer` processes. 
  A `t:Fact.QueryItem.t/0` contains the metadata needed to subscribe to the correct indexers so the subscription
  and coordinate when events become "visible" to the subscriber.
    
  Could a `t:Fact.Query.t/0` be decompiled back into an AST so we could reconstruct that information? Probably! But
  for now, I'd rather spend my time building other things. If you're like my good buddy Tim and love spelunking through
  abstract syntax trees, I'll happily take your pull request. 

  ## Options

  ### position:
    
  Set the position to begin reading the event source.

    * `:start` **(default)** - the position immediately **before the first item** in the event source
    * `:end` - the position immediately **after the last item** in the event source
    * Or a non-negative integer representing the absolute position within the source

  > #### Live mode only {: .tip}
  >
  > If you're not interested in past events, set `position: :end` to move directly into live mode.


  ### subscriber:
    
  Specifies the PID of the process that will receive subscription message. Defaults to `self()`.
  """
  @spec subscribe(database_id(), subscribe_source(), subscribe_options()) :: {:ok, pid()}
  def subscribe(database_id, event_source, options \\ [])

  def subscribe(database_id, :all, options) when is_binary(database_id) and is_list(options) do
    Fact.CatchUpSubscription.All.start_link([database_id: database_id] ++ options)
  end

  def subscribe(database_id, {:stream, stream}, options)
      when is_binary(database_id) and is_binary(stream) and is_list(options) do
    Fact.CatchUpSubscription.Stream.start_link(
      [database_id: database_id, stream: stream] ++ options
    )
  end

  def subscribe(database_id, {:index, indexer_id, index}, options)
      when is_binary(database_id) and is_tuple(indexer_id) and tuple_size(indexer_id) == 2 and
             is_binary(index) and
             is_list(options) do
    Fact.CatchUpSubscription.Index.start_link(
      [database_id: database_id, indexer_id: indexer_id, index: index] ++ options
    )
  end

  def subscribe(database_id, {:query, %Fact.QueryItem{} = query}, options)
      when is_binary(database_id) and is_list(options) do
    subscribe(database_id, {:query, List.wrap(query)}, options)
  end

  def subscribe(database_id, {:query, [%Fact.QueryItem{} | _] = query_items}, options)
      when is_binary(database_id) and is_list(query_items) and is_list(options) do
    Fact.CatchUpSubscription.Query.start_link(
      [database_id: database_id, query_items: query_items] ++ options
    )
  end
end
