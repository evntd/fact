defmodule Fact do
  @moduledoc """
  Fact is an **event-sourcing database**, an append-only event store designed to make
  event-driven systems explicit, observable, and mechanically simple.

  Rather than persisting the resulting state of your system, Fact records the
  sequence of domain events that led to it. These events form a durable,
  ordered ledger that serves as the single source of truth for projections,
  workflows, read models, analytics, and audit requirements.

  ## Core Ideas

  Fact is built around a few intentional concepts:

  * **Events are facts** - they describe something that happened in the domain  
  * **The ledger is append-only** - state is derived, never mutated in place  
  * **Streams define static consistency boundaries** - typically aligned with DDD aggregates  
  * **Queries define dynamic consistency boundaries** - enabling emergent boundaries based
    on event types, tags, and data-level conditions  
  * **Storage is transparent** - files on disk, deterministic layouts, no black boxes; easy
    to inspect and manipulate (but never change) with standard OS tooling such as `grep`,
    `sed`, `awk`, `jq` and plenty of other command-line utilities.

  The goal is not to be a general-purpose database, but a focused tool for
  systems that benefit from traceable history, replayable behavior, and explicit
  domain modeling.

  ## What Fact Provides

  * A **global event ledger** (the ordered history of the entire database)
  * **Event streams** for optimistic-concurrency-safe aggregate boundaries
  * **Ledger-level conditional appends** to prevent duplicates and conflicting writes
  * **Queries and indexes** for building read and processing workflows
  * **Subscription APIs** for reacting to new events as they are committed
  * A configurable **event schema**, record format, and identifier strategy

  Fact is intentionally small in surface-area but powerful in composition:
  everything builds on top of event persistence and deterministic ordering.

  ## Consistency & Concurrency Model

  Fact provides two complementary consistency mechanisms:

  * **Stream expectations** - optimistic concurrency within a single stream  
  * **Append conditions** - optional duplicate / conflict detection at the ledger level  

  These tools allow you to model invariants where they belong **in the domain**, 
  rather than inside storage mechanics.

  ## Durability, Ordering, and Guarantees

  * Events are written **atomically and in order**
  * Positions are **stable and monotonic within their scope**
  * Reads are deterministic and replayable

  However, Fact does not promise distributed consensus, global locks, or
  cross-process transactional semantics. It is currently designed for single-writer
  durability with cooperative correctness enforced by the application model.

  ## Configuration & Event Shape

  The structure of an event record is defined by `Fact.Event.Schema`, including:

  * field names for type, data, metadata, and tags  
  * storage keys for positions, timestamps, and stream attributes  
  * identifier and encoding strategies

  Events are represented as plain maps before being persisted and enriched with
  system metadata at commit-time.
    
  ## When to Use Fact

  Fact works best when:

  * history matters more than just current state
  * debugging and auditability are important
  * systems benefit from replay and projection
  * domain events are a first-class modeling tool

  Fact excels when behavior is temporal and state is derived.

  ## Getting Started

  Typical workflow:

  1. Create and open a database
  2. Append events to streams or the ledger
  3. Read from streams, queries, or indexes
  4. Build projections and workflows from subscriptions

  See the documentation for `append/4`, `append_stream/5`, `read/3`,
  and `subscribe/3` for operational details.    

  > #### Here there be 🐉🐉 {: .warning} 
  > 
  > Elixir's type system isn't as strict as say F#. So I've done my best to describe the types, their 
  > format, and encoding. Many of these are not enforced, and supplying other types may compile but 
  > produce errors or unexpected behavior. 
  >
  > Just use the system as I intended, and it'll just work 😉.
  """

  @typedoc """
  A condition that **must not** be satisfied in order for an append operation to succeed.
    
  An `t:Fact.append_condition/0` allows you to express causal or state-dependent constraints
  using queries against the event ledger. If the condition evaluates as a match, the append 
  is rejected.
    
  When `nil`, no conditional check is performed. The events are always appended.
    
  When a `t:fail_if_match/0` value is provided, the append function will fail if the 
  query matches any events already present in the ledger.
    
  When a `{fail_if_match, after_position}` tuple is provided, the append function will 
  fail if the query matches any events present in the ledger found after the specified position.
  """
  @type append_condition ::
          nil | fail_if_match() | {fail_if_match(), after_position :: non_neg_integer()}

  @typedoc """
  A condition that fails the append operation when matching events are found.
    
  May be expressed as a `t:Fact.Query.t/0`, a single `t:Fact.QueryItem.t/0`, or a list
  of `t:Fact.QueryItem.t/0`. All forms represent a predicate function evaluated against
  events committed to the ledger.
  """
  @type fail_if_match :: Fact.Query.t() | Fact.QueryItem.t() | [Fact.QueryItem.t()]

  @typedoc """
  Options for `append/5`.
    
    * `:timeout` **(default: 5000)** - the maximum time (in milliseconds) to wait for the append operation to compile.
  """
  @type append_options :: [timeout: timeout()]

  @typedoc """
  Provides optimistic concurrency control when appending to event streams.
  """
  @type append_stream_expectation() :: non_neg_integer() | :any | :none | :exists

  @typedoc """
  Options for `append_stream/5`.
    
    * `:timeout` **(default: 5000)** - the maximum time (in milliseconds) to wait for the append operation to compile.
  """
  @type append_stream_options :: [timeout: timeout()]

  @typedoc """
  A unique identifier for a Fact database.
    
  It is used as the primary handle for all database operations. Many 
  Fact subsystems use this identifier to retrieve the database context 
  in order to perform file and storage operations.
  """
  @type database_id :: uuid_v4_base32_uppercase_sans_padding()

  @typedoc """
  The user-friendly name of the Fact database. 
  """
  @type database_name :: String.t()

  @typedoc """
  Represents an event before being written to the event store.

  At minimum, it must define a `:type` key.  

  It may also include:
    * `:data` - a map of custom data
    * `:metadata` - a map of custom data about the data
    * `:tags` - a list of custom identifiers to aid in defining context boundaries

  > #### Event ids are system defined {: .info}
  >
  > Apologies, event ids are system generated at this time.
  """
  @type event :: %{
          required(:type) => event_type,
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

  @doc """
  Appends one or more events to the ledger.

  The ledger represents the full, ordered event history for a database. In
  addition to standard optimistic concurrency mechanisms at the stream level,
  Fact also supports conditional appends at the ledger level to help prevent
  duplicate or conflicting writes.

  These conditions are expressed through the `append_condition` argument.

  When appending, you may provide one of the following:

    * `nil` **(default)** — no condition is applied; the events are always appended

    * a `t:Fact.fail_if_match/0` value — the append will be rejected if the query
      matches any existing events anywhere in the ledger

    * `{fail_if_match, after_position}` — the append will be rejected if the
      query matches any events whose position is strictly greater than
      `after_position`. 

  If the condition is violated, the append is rejected and an error tuple including
  a `Fact.ConcurrencyError` is returned. 

  On success, each appended event record is enriched with the `:event_id`, 
  `:event_store_position`, `:event_store_timestamp` fields defined by the configured 
  event schema. In addition the field keys used to define events (`type`, `data`, 
  `metatadata` and `tags`) are renamed according to the configured schema. 

  The function returns `{:ok, last_position}`, where `last_position` is the store
  position of the last appended event.

  ## Examples

  Append without conditions:

      iex> {:ok, pos} = Fact.append(db, %{type: "user_registered", data: %{id: 123}})
      {:ok, 42}
    
  Append a duplicate:
    
      iex> {:ok, pos} = Fact.append(db, %{type: "user_registered", data: %{id: 123}})
      {:ok, 43}

  Prevent a third duplicate using a `fail_if_match` query:

      iex> import Fact.QueryItem
      iex> fail_if_match = types("user_registered") |> data(id: "123")
      iex> Fact.append(db, %{type: "user_registered", data: %{id: 123}}, fail_if_match)
      {:error, %Fact.ConcurrencyError{source: :all, expected: 0, actual: 42}}

  Allow the append only if no matching events exist **after** a given position:
      
      iex> Fact.append(db, %{type: "user_registered"}, {fail_if_match, last_pos})
      {:ok, 44}

    
  The final example was intentionally contrived; in practice, append conditions are
  best applied to model explicit business invariants. For deeper guidance and 
  real-world usage patterns, see the [Dynamic Consistency Boundary](https://dcb.events)
  website.  
  """
  @spec append(
          Fact.database_id(),
          Fact.event() | [Fact.event(), ...],
          Fact.append_condition(),
          Fact.append_options()
        ) :: {:ok, Fact.event_position()} | {:error, term()}
  def append(
        database_id,
        events,
        append_condition \\ nil,
        opts \\ []
      ) do
    Fact.EventLedger.commit(database_id, events, append_condition, opts)
  end

  @doc """
  Appends one or more events to a stream.
    
  Event streams define a consistency boundary for a set of related events. To 
  preserve this boundary, Fact, like many event stores uses stream position
  expectations to provide optimistic concurrency control.
      
  When appending to a stream, you may provide an expected position value:
    
    * A non negative integer - verifies that the stream is currently at that exact
      position before appending
    * `:any` **(default)** - no check is performed, the events are just appended
    * `:none` - ensures the stream does not yet exist (equivalent to `0`)
    * `:exists` - ensures the stream already exists (i.e. position ≥ 1)
    
  If the expectation is not met, the append is rejected and a 
  `{:error, %Fact.ConcurrencyError{}}` is returned.

  On success, each appended event record is enriched with the stream fields as defined 
  by `:event_stream_id` and `:event_stream_position` of the configured schema 
  (see `Fact.Event.Schema`). The function returns `{:ok, last_stream_position}`, where
  the last_stream_position refers to the stream position of the final event written
  to the stream.
    
  It is strongly recommnded that you persis this returned position in your application
  state and reuse it in subsequent calls to `append_stream/5` to ensure consistency.

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
    
      iex> Fact.append_stream(db, %{type: "MySecondEvent"}, "myteststream", 1)
      {:ok, 2}
    
  Append a third event, but provide an invalid expected position.
    
      iex> Fact.append_stream(:mydb, %{type: "MyThirdEvent"}, "myteststream", 1)
      {:error, %Fact.ConcurrencyError{source: "myteststream", actual: 2, expected: 1}}

  Append multiple events to a **new** stream.
    
      iex> Fact.append_stream(db, [%{type: "foo"}, %{type: "bar"}, %{type: "baz"}], "foobarbaz-1", :none)
      {:ok, 3}
    
  Expect a stream to not exist, yet it does.

      iex> Fact.append_stream(db, %{type: "foo"}, "foobarbaz-1", :none)
      {:ok, %Fact.ConcurrencyError{source: "foobarbaz-1", expected: :none, actual: 3}}

  Expect a stream to exist, when it does not exist.
    
      iex> Fact.append_stream(db, %{type: "foo"}, "foo-1", :exists)
      {:ok, %Fact.ConcurrencyError{source: "foo-1", expected: :exists, actual: 0}}

  """
  @spec append_stream(
          Fact.database_id(),
          Fact.event() | [Fact.event(), ...],
          Fact.event_stream_id(),
          Fact.append_stream_expectation(),
          Fact.append_stream_options()
        ) :: {:ok, Fact.event_position()} | {:error, term()}
  def append_stream(
        database_id,
        events,
        event_stream,
        expected_position \\ :any,
        options \\ []
      ) do
    Fact.EventStreamWriter.commit(database_id, events, event_stream, expected_position, options)
  end

  @doc """
  Initializes a Fact database at the given filesystem path.
    
  This function ensures that the `Fact.Supervisor` is running and then starts the database 
  supervision tree as a child process. Once the `Fact.DatabaseSupervisor` is running, the
  database id is returned, and you may use it as a handle for appending events, reading
  and subscribing to event sources.
    
  ## Examples
    
    Opens a new database.
    
      iex> {:ok, db} = Fact.open("data/turtles")
      {:ok, "EF73AQJ6S5HHZE5PMX7ZP254QQ"}
    
    Subsequent calls to the same path return the same database id...with the same BEAM.
    
      iex> {:ok, db2} = Fact.open("data/turtles")
      {:ok, "EF73AQJ6S5HHZE5PMX7ZP254QQ"}
    
    Keep that database running. Try to open the database again in another instance
    of IEx. You'll get a database locked error similar to the following: 

      iex> Fact.open("data/turtles")
      {:error, :database_locked,
       %{
         "locked_at" => "2026-01-07T06:18:57.669109Z",
         "mode" => "run",
         "node" => "nonode@nohost",
         "os_pid" => "933078",
         "vm_pid" => "#PID<0.232.0>"
       }}

    Remember to use `mix fact.create -p <path>` to create a database before attempting
    to open it. 

      iex> Fact.open("does/not/exist")
      {:error, :database_not_found}

  """
  @spec open(Path.t()) :: {:ok, database_id()} | {:error, term()}
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
    Fact.Database.read_none(database_id, Keyword.put_new(options, :eager, true))
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
