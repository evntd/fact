[![Test](https://github.com/evntd/fact/actions/workflows/publish.yml/badge.svg)](https://github.com/evntd/fact/actions/workflows/publish.yml)
[![fact version](https://img.shields.io/hexpm/v/fact.svg)](https://hex.pm/packages/fact)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/fact/)
[![Hex.pm](https://img.shields.io/hexpm/dt/fact.svg)](https://hex.pm/packages/)

<div style="display: flex; justify-content: center;">
  <img alt="logo" src=".github/assets/logo.png" width="424">
</div>

## A 🥾

**Fact** is an **Elixir library** that provides a file system based event store database.

## Features

- Traditional event sourcing capabilities:
    - Append events to event streams
    - Read events from specific event streams or all events in the event store
    - Subscribe to specific event streams or all events in the event store
    - [Optimistic concurrency control](https://en.wikipedia.org/wiki/Optimistic_concurrency_control)
- Compliant with the [Dynamic Consistency Boundary specification](https://dcb.events/specification/)
- **Read events from built-in indexes and custom queries.**
- **Subscribe to built-in indexes and custom queries.**
- Just-in-time indexing for event data queries.
- "Pseudo-WORM" storage<sup>[1](#fn1)</sup>
- Supports multiple instances for siloed isolation in multi-tenancy setups
- Configurable [Content-Addressable Storage (CAS)](https://en.wikipedia.org/wiki/Content-addressable_storage)
- Configurable event schemas
- Backup & Restore tasks
- Supported on Elixir 1.13+ and OTP 25+

#### Coming soon...

- More user guides
- Write-Ahead Log (WAL) to make this crash-proof. It's only near crash-proof currently.
- Data tampering verification task (for CAS)
- Custom Indexers

#### Coming later...

- Telemetry
- Merkle Mountain Range
    - inclusion proofs, this event exists in the ledger at position N.
    - doesn't prevent tampering, but proves it did or didn't happen
    - Needs one of these 🤔:
        - signed checkpoints
        - cross-system anchoring
        - client-held receipts
- Proof of scale
    - Target: 1M events per day, <= 86.4 ms per write, 11.5 events per second
    - Honestly not trying to build for global scale, if that's what you need use Axon, Kurrent, or UmaDB
- Full stack example application
- A network protocol to enable non-BEAM based languages to interop.
- A gossip protocol to coordinate multiple BEAM nodes

#### Some time in the future...

- Graphical user interface to manage and operate the database (like a pgAdmin or Sql Server Management Studio)

## Installation

The package can be installed by adding `fact` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:fact, "~> 0.2.1"}
  ]
end
```

Then create a database instance.

```sh
$ mix fact.create -p data/turtles
```

## Basic Usage

```elixir
# Start a database instance
iex> {:ok, db} = Fact.open("data/turtles")

# Create an event
iex> event = %{
...>   type: "egg_hatched",
...>   data: %{
...>     name: "Turts"
...>   }
...> }

# Append the event to a stream
iex> {:ok, pos} = Fact.append_stream(db, event, "turtle-1")

# Read the event stream
iex> Fact.read(db, {:stream, "turtle-1"})
[
  %{
    "event_data" => %{"name" => "Turts"},
    "event_id" => "3bb4808303c847fd9ceb0a1251ef95da",
    "event_tags" => []
    "event_type" => "egg_hatched",
    "event_metadata" => %{},
    "store_position" => 1,
    "store_timestamp" => 1765039106962264,
    "stream_id" => "turtle-1",
    "stream_position" => 1
  }
]
```

## Event Tags & Queries

```elixir
# Start a database instance
iex> {:ok, db} = Fact.open("data/turtles")

# Create an event
iex> event = %{
...>   type: "clutch_laid",
...>   data: %{
...>     eggs_laid: 107
...>   },
...>   tags: ["clutch:c1"]
...> }

# Append the tagged event
iex> {:ok, pos} = Fact.append(db, event)

# Create and append another tagged event
iex> event = %{
...>   type: "egg_hatched",
...>   data: %{
...>     egg_id: 42
...>   },
...>   tags: ["clutch:c1", "egg:42"]
...> }
iex> {:ok, pos} = Fact.append(db, event)

# Query by the clutch tag that is defined on both appended events 
iex> import Fact.QueryItem
iex> Fact.read(db, {:query, tags("clutch:c1")})
[
  %{
    "event_data" => %{"eggs_laid" => 107},
    "event_id" => "0405bad46f1b407796c3e874c45664af",
    "event_metadata" => %{},
    "event_tags" => ["clutch:c1"],
    "event_type" => "clutch_laid",
    "store_position" => 2,
    "store_timestamp" => 1769814807951055
  },
  %{
    "event_data" => %{"egg_id" => 42},
    "event_id" => "7c7e42353fa045c4a6a4320ecb4591b7",
    "event_metadata" => %{},
    "event_tags" => ["clutch:c1", "egg:42"],
    "event_type" => "egg_hatched",
    "store_position" => 3,
    "store_timestamp" => 1769814855595808
  }
]

# Query by the egg tag that was only on one of the events
iex> Fact.read(db, {:query, tags("egg:42")})
[
  %{
    "event_data" => %{"egg_id" => 42, "name" => "Turts"},
    "event_id" => "7c7e42353fa045c4a6a4320ecb4591b7",
    "event_metadata" => %{},
    "event_tags" => ["clutch:c1", "egg:42"],
    "event_type" => "egg_hatched",
    "store_position" => 3,
    "store_timestamp" => 1769814855595808
  }
]
```

### 🦶🎶

<small id="fn1">1 - Its "pseudo-WORM" because immutability is enforced at the filesystem level by marking events
as read-only. This prevents modification during normal operation, but does not provide hardware-level or regulatory WORM
enforcement.</small>