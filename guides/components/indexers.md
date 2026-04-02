# Indexers

This guide explains how **event indexers** work in Fact, describes each of the built-in indexers, and walks through
building and configuring **custom indexers** for your application.

At a high level:

- Indexers are **event projections** that filter the event ledger and produce keyed, ordered sets of event record IDs
- Each indexer runs as a **supervised GenServer** that subscribes to all events and maintains its own index files
- Indexes are **append-only** and **safe to delete** — they rebuild automatically on next startup
- Custom indexers implement a single callback and are configured via `Fact.open/2`

## How Indexers Work

Every indexer follows the same lifecycle:

1. **Startup** — the indexer subscribes to all events via `Fact.EventPublisher` and reads its checkpoint (the last
   store position it processed)
2. **Rebuild** — any events after the checkpoint are replayed from the ledger, and the index is brought up to date
3. **Live** — as new events are appended, the indexer receives `{:appended, record}` messages and updates its index
   in real time

For each event, the indexer calls its `index_event/3` callback. The callback returns:

- `nil` — the event is skipped
- A string value — a single index entry is written
- A list of string values — an entry is written to each corresponding index file

Index files are stored under `/indices/<indexer_name>/<indexer_key>/`. Each distinct value returned by the callback
produces its own file containing the event record IDs that matched, ordered by store position.

After processing each event, the indexer writes its checkpoint so it can resume from the correct position after a
restart.

## Built-in Indexers

Fact starts six indexers automatically with every database. These power the core read APIs and query system.

### Event Stream Indexer

**Module:** `Fact.EventStreamIndexer`

Indexes every event by its stream ID. Creates one index file per stream.

```
/indices/event_stream/turtle_nest-1234
/indices/event_stream/__fact
```

### Event Type Indexer

**Module:** `Fact.EventTypeIndexer`

Indexes every event by its type. Creates one index file per event type.

```
/indices/event_type/ClutchLaid
/indices/event_type/EggHatched
```

### Event Tags Indexer

**Module:** `Fact.EventTagsIndexer`

Indexes events by each of their tags. A single event with multiple tags produces entries in multiple index files.

```
/indices/event_tags/turtle:t1
/indices/event_tags/clutch:c1
```

### Event Stream Category Indexer

**Module:** `Fact.EventStreamCategoryIndexer`

Indexes events by the **category** portion of the stream ID — the first segment when split on the separator
(default: `"-"`). For example, stream `turtle_nest-1234` produces category `turtle_nest`.

```
/indices/event_stream_category/turtle_nest
/indices/event_stream_category/__fact
```

### Event Streams Indexer

**Module:** `Fact.EventStreamsIndexer`

Indexes only the **first event** of each stream. Produces a single index file called `index` containing the record
IDs for all stream-opening events. Useful for discovering all aggregate instances in the system.

```
/indices/event_streams/index
```

### Event Streams by Category Indexer

**Module:** `Fact.EventStreamsByCategoryIndexer`

Indexes the **first event** of each stream, grouped by stream category. Produces one index file per category, each
containing the first event of every stream in that category. Useful for queries like "get all orders" or "get all
customers."

```
/indices/event_streams_by_category/turtle_nest
/indices/event_streams_by_category/order
```

### Event Data Indexer

**Module:** `Fact.EventDataIndexer`

A parameterized indexer that extracts the value of a specific field from the event data payload. Each instance
targets a single key and is identified by that key.

```
/indices/event_data/user_id/user_123
/indices/event_data/user_id/user_456
/indices/event_data/tenant_id/acme
```

## Custom Indexers

Custom indexers allow you to define application-specific indexes that are maintained automatically as events are
appended. A custom indexer is a module that uses `Fact.EventIndexer` and implements the `index_event/3` callback.

### Defining a Custom Indexer

```elixir
defmodule MyApp.UserIndexer do
  use Fact.EventIndexer

  @impl true
  def index_event(schema, event, _opts) do
    unless is_nil(user_id = Map.get(event[schema.event_data], "user_id")),
      do: to_string(user_id)
  end
end
```

The `schema` argument provides the field names for the configured event schema (e.g., `schema.event_data`,
`schema.event_type`, `schema.event_stream_id`). This ensures your indexer works regardless of which event schema
the database is configured with.

The callback must return `nil`, a string, or a list of strings.

### Returning Multiple Values

An indexer can create entries in multiple index files for a single event by returning a list. This is how the
built-in `Fact.EventTagsIndexer` works — it returns the full list of tags, and each tag gets its own index entry.

```elixir
defmodule MyApp.MentionIndexer do
  use Fact.EventIndexer

  @impl true
  def index_event(schema, event, _opts) do
    case Map.get(event[schema.event_data], "mentions") do
      nil -> nil
      mentions -> Enum.map(mentions, &to_string/1)
    end
  end
end
```

### Using Options

The third argument to `index_event/3` is a keyword list of options passed through from the configuration. This
enables a single module to serve multiple purposes.

```elixir
defmodule MyApp.MetadataIndexer do
  use Fact.EventIndexer

  @impl true
  def index_event(schema, event, opts) do
    field = Keyword.fetch!(opts, :indexer_key)

    unless is_nil(value = Map.get(event[schema.event_metadata], field)),
      do: to_string(value)
  end
end
```

### Using Keys for Parameterized Instances

A `:key` distinguishes multiple instances of the same indexer module. Each instance gets its own checkpoint file and
index directory, so they operate independently.

```elixir
Fact.open("data/my_app",
  indexers: [
    {MyApp.MetadataIndexer, key: "correlation_id", options: [indexer_key: "correlation_id"]},
    {MyApp.MetadataIndexer, key: "causation_id", options: [indexer_key: "causation_id"]}
  ]
)
```

This produces:

```
/indices/metadata/correlation_id/<values...>
/indices/metadata/causation_id/<values...>
```

## Configuration

Custom indexers are passed to `Fact.open/2` via the `:indexers` option. Each entry can be a bare module or a
`{module, opts}` tuple.

```elixir
{:ok, db} = Fact.open("data/my_app",
  indexers: [
    MyApp.UserIndexer,
    MyApp.MentionIndexer,
    {Fact.EventDataIndexer, key: "tenant_id"},
    {Fact.EventDataIndexer, key: "order_id"}
  ]
)
```

The same configuration works when starting Fact under a supervision tree:

```elixir
children = [
  {Fact.Supervisor,
    databases: [
      {"data/my_app",
        indexers: [
          MyApp.UserIndexer,
          {Fact.EventDataIndexer, key: "tenant_id"}
        ]}
    ]}
]
```

Or via application configuration:

```elixir
# config/config.exs
config :my_app, Fact,
  databases: [
    {"data/my_app",
      indexers: [
        MyApp.UserIndexer,
        {Fact.EventDataIndexer, key: "tenant_id"}
      ]}
  ]

# application.ex
children = [
  {Fact.Supervisor, Application.get_env(:my_app, Fact)}
]
```

Custom indexers are **additive** — they run alongside the six built-in indexers, which are always started.

## Reading from Custom Indexes

Once a custom indexer is running, you can read from its index using `Fact.read/3` with the `:index` source:

```elixir
# Read all events for a specific user
Fact.read(db, {:index, {MyApp.UserIndexer, nil}, "user_123"})

# Read all events for a tenant (via EventDataIndexer)
Fact.read(db, {:index, {Fact.EventDataIndexer, "tenant_id"}, "acme"})
```

Custom indexes also work with subscriptions:

```elixir
# Subscribe to a custom index
Fact.subscribe(db, {:index, {MyApp.UserIndexer, nil}, "user_123"})
```

In practice, it is common to wrap index reads in a helper function that hides the indexer tuple and forwards
read options to `Fact.read/3`:

```elixir
defmodule MyApp.Users do
  @indexer_id {MyApp.UserIndexer, nil}

  def read(db, user_id, read_opts \\ []) do
    Fact.read(db, {:index, @indexer_id, user_id}, read_opts)
  end
end
```

```elixir
# Get the last 10 events for a user, most recent first
MyApp.Users.read(db, "user_123", direction: :backward, position: :end, count: 10)

# Get all events for a user as record tuples
MyApp.Users.read(db, "user_123", result: :record)
```

## Index File Layout

All indexers write to the same directory structure under the database's indices path:

```
indices/
├── event_stream/           # EventStreamIndexer
│   └── <stream_id>
├── event_type/             # EventTypeIndexer
│   └── <event_type>
├── event_tags/             # EventTagsIndexer
│   └── <tag>
├── event_stream_category/  # EventStreamCategoryIndexer
│   └── <category>
├── event_streams/          # EventStreamsIndexer
│   └── index
├── event_streams_by_category/  # EventStreamsByCategoryIndexer
│   └── <category>
├── event_data/             # EventDataIndexer
│   └── <key>/
│       └── <value>
└── user/                   # MyApp.UserIndexer (custom)
    └── <user_id>
```

The directory name for a custom indexer is derived from its module name. `MyApp.UserIndexer` becomes `user`,
`MyApp.OrderFulfillmentIndexer` becomes `order_fulfillment`. This can be overridden by passing `:name` to the
`use Fact.EventIndexer` macro:

```elixir
defmodule MyApp.UserIndexer do
  use Fact.EventIndexer, name: "app_user"

  # ...
end
```

Each indexer directory also contains a `.checkpoint` file that tracks the last processed store position.
