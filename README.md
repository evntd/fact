[![Test](https://github.com/evntd/fact/actions/workflows/elixir.yml/badge.svg)](https://github.com/evntd/fact/actions/workflows/elixir.yml)

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
- Configurable event schemas<sup>[2](#fn2)</sup>
- Supported on Elixir 1.13+ and OTP 25+

#### Coming soon...

- User guides
- Backup task
- Restore task
- Data tampering verification task (for CAS)

#### Coming later...

- Proof of scale
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
    {:fact, "~> 0.1.0"}
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
iex> Fact.read(db, {:stream, "turtle-1"}) |> Enum.to_list()
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

### 🦶🎶

<small id="fn1">1 - Its "pseudo-WORM" because immutability is enforced at the filesystem level by marking events
as read-only. This prevents modification during normal operation, but does not provide hardware-level or regulatory WORM
enforcement.</small>

<small id="fn2">2 - The groundwork has been laid, but still requires work in system genesis and bootstrapping.</small>