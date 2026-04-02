[![Test](https://github.com/evntd/fact/actions/workflows/publish.yml/badge.svg)](https://github.com/evntd/fact/actions/workflows/publish.yml)
[![fact version](https://img.shields.io/hexpm/v/fact.svg)](https://hex.pm/packages/fact)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/fact/)
[![Hex.pm](https://img.shields.io/hexpm/dt/fact.svg)](https://hex.pm/packages/)

<div style="display: flex; justify-content: center;">
  <img alt="logo" src=".github/assets/logo.png" width="424">
</div>

## A 🥾

**Fact** is a file system based **event store database** for Elixir. It records the sequence of domain events
that led to your system's current state — a durable, ordered ledger that serves as the single source of truth
for projections, workflows, read models, analytics, and audit requirements.

Events are just files on disk. Deterministic layouts, no black boxes. Inspect and manipulate your data with
`grep`, `jq`, `sed`, and any other tool you already know.

## Quick Start

Add `fact` to your dependencies:

```elixir
def deps do
  [
    {:fact, "~> 0.3.0"},
    {:jason, "~> 1.4"}  # required on Elixir 1.17 and earlier
  ]
end
```

Create and use a database:

```sh
$ mix deps.get
$ mix fact.create -p data/turtles
```

```elixir
# Open the database
iex> {:ok, db} = Fact.open("data/turtles")

# Append an event to a stream
iex> {:ok, pos} = Fact.append_stream(db, %{
...>   type: "egg_hatched",
...>   data: %{name: "Turts"}
...> }, "turtle-1")

# Read the stream back
iex> Fact.read(db, {:stream, "turtle-1"})
[
  %{
    "event_type" => "egg_hatched",
    "event_data" => %{"name" => "Turts"},
    "event_id" => "3bb4808303c847fd9ceb0a1251ef95da",
    "event_tags" => [],
    "event_metadata" => %{},
    "store_position" => 1,
    "store_timestamp" => 1765039106962264,
    "stream_id" => "turtle-1",
    "stream_position" => 1
  }
]
```

## Features

### Event Sourcing Fundamentals

- **Append** events to named streams or the global ledger
- **Read** from streams, the global ledger, indexes, or composed queries
- **Subscribe** to any event source with catch-up-then-live semantics
- **Optimistic concurrency control** on streams — enforce invariants where they belong, in the domain
- **Conditional appends** at the ledger level for duplicate and conflict detection

### Indexing & Queries

- Built-in indexes by **stream**, **event type**, **tags**, **stream category**, and **event data fields**
- Compose queries with set operations — `tags("admin") |> types("user_created") |> data(name: "Alice")`
- Just-in-time indexing: no upfront schema, indexes build themselves as events arrive
- Query evaluation never reads event payloads — only index files and the ledger

### Durability & Integrity

- **Write-Ahead Log** prevents data loss during crashes, with configurable fsync and segment rotation
- **Merkle Mountain Range** for tamper detection — verify database integrity, create and verify cryptographic proofs
- **Pseudo-WORM storage**<sup>[1](#fn1)</sup> — events are marked read-only after write

### Storage & Configuration

- **Transparent file storage** — events are files you can inspect with standard OS tools
- **Content-Addressable Storage (CAS)** mode for hash-based record naming
- **Configurable event schemas** — choose from built-in schemas or define your own
- **Pluggable architecture** — encoders, decoders, storage layouts, file strategies, and ID generation are all swappable via the [Seam Architecture](https://hexdocs.pm/fact/seam-architecture.html)
- **Multiple database instances** for siloed isolation in multi-tenancy setups
- **Backup & Restore** mix tasks
- Supported on **Elixir 1.13+** and **OTP 25+**

## Dynamic Consistency Boundaries

Fact is compliant with the [Dynamic Consistency Boundary (DCB) specification](https://dcb.events/specification/).

Traditional event stores enforce consistency at the stream level — one aggregate, one stream. DCB goes further:
it lets you define consistency boundaries dynamically using **queries** over event types and tags. This means
your consistency boundaries can cross streams, evolve over time, and model real-world invariants that don't fit
neatly into a single aggregate.

Fact implements the full DCB specification and **extends it** with queries over **event data fields**. This
lets you define boundaries based on the actual content of your events — not just their types and tags.

In Fact, a query *is* a consistency boundary. Combine `tags`, `types`, and `data` conditions to select exactly
the events that matter for a given decision, then use conditional appends to enforce invariants across them.

```elixir
import Fact.QueryItem

# DCB: query by tags and types
user_boundary = tags("user:42")
admin_users = tags("admin") |> types("user_created")

# Fact extension: query by event data fields
by_name = tags("admin") |> types("user_created") |> data(name: "Alice")

# Read from a dynamic boundary
Fact.read(db, {:query, by_name})
```

## Event Tags & Queries

Tags are lightweight labels attached to events. They power Fact's query system and enable DCB.

```elixir
# Append tagged events
{:ok, _} = Fact.append(db, %{
  type: "clutch_laid",
  data: %{eggs: 107},
  tags: ["clutch:c1"]
})

{:ok, _} = Fact.append(db, %{
  type: "egg_hatched",
  data: %{egg_id: 42},
  tags: ["clutch:c1", "egg:42"]
})

# Query by tag
import Fact.QueryItem
Fact.read(db, {:query, tags("clutch:c1")})   # both events
Fact.read(db, {:query, tags("egg:42")})       # just the hatching
```

## Subscriptions

React to events in real time with catch-up subscriptions. They replay history from a given position,
then seamlessly transition to live events as they arrive.

```elixir
# Subscribe to all events
Fact.subscribe(db, :all)

# Subscribe to a specific stream
Fact.subscribe(db, {:stream, "turtle-1"})

# Subscribe to a query
import Fact.QueryItem
Fact.subscribe(db, {:query, tags("clutch:c1")})

# Events arrive as messages
receive do
  {:events, events} -> IO.inspect(events)
end
```

## Configuration

Fact ships with sensible defaults. Enable optional subsystems as needed:

```elixir
{:ok, db} = Fact.open("data/turtles",
  # In-memory record cache (LFU eviction)
  cache: [max_size: 512 * 1024 * 1024],

  # Write-ahead log for crash recovery
  wal: [enable_fsync: true, sync_interval: 200],

  # Merkle Mountain Range for tamper detection (requires CAS mode)
  merkle: [batch_size: 10, flush_interval: 1_000]
)
```

See the [Hex Docs](https://hexdocs.pm/fact/) for detailed guides on each subsystem.

## Supervision Tree

Add Fact to your application's supervision tree:

```elixir
# application.ex
def start(_type, _args) do
  children = [
    {Fact.Supervisor,
      databases: [
        {"data/turtles", wal: [enable_fsync: true]}
      ]}
  ]

  Supervisor.start_link(children, strategy: :one_for_one)
end
```

Look up a database by name at runtime:

```elixir
{:ok, db} = Fact.Registry.get_database_id("turtles")
```

## Mix Tasks

| Task | Description |
|------|-------------|
| `mix fact.create -p <path>` | Create a new database |
| `mix fact.backup --path <path> --output <file>` | Back up a database to a zip file |
| `mix fact.restore --path <path> --input <file>` | Restore a database from a backup |
| `mix fact.merkle.verify -p <path>` | Verify database integrity |
| `mix fact.merkle.root -p <path>` | Print the Merkle root hash |
| `mix fact.merkle.create_proof -p <path> --position <n>` | Create an inclusion proof |
| `mix fact.merkle.verify_proof --proof <file>` | Verify an inclusion proof |

## Coming in v0.4.0

- **Encryption at rest** — AES-256-GCM authenticated encryption for event record files, with envelope encryption (DEK/KEK) and recovery key support
- **Custom indexers** — define application-specific indexes with a single callback, configured via `Fact.open/2`
- **Metadata indexer** — built-in indexer for event metadata fields (correlation IDs, tenant IDs, etc.)

## Roadmap

- Telemetry
- Full stack example application
- A network protocol to enable non-BEAM languages to interop
- A gossip protocol to coordinate multiple BEAM nodes
- Graphical management interface

## Documentation

- [Getting Started](https://hexdocs.pm/fact/getting-started.html)
- [Process Model](https://hexdocs.pm/fact/process-model.html)
- [Queries and Indexes](https://hexdocs.pm/fact/queries-and-indexes.html)
- [Write-Ahead Log](https://hexdocs.pm/fact/write-ahead-log.html)
- [Record Cache](https://hexdocs.pm/fact/record-cache.html)
- [Merkle Mountain Range](https://hexdocs.pm/fact/merkle-mountain-range.html)
- [Seam Architecture](https://hexdocs.pm/fact/seam-architecture.html)
- [API Reference](https://hexdocs.pm/fact/api-reference.html)

### 🦶🎶

<small id="fn1">1 - Its "pseudo-WORM" because immutability is enforced at the filesystem level by marking events
as read-only. This prevents modification during normal operation, but does not provide hardware-level or regulatory WORM
enforcement.</small>
