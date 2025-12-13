[![Test](https://github.com/evntd/fact/actions/workflows/elixir.yml/badge.svg)](https://github.com/evntd/fact/actions/workflows/elixir.yml)

<div>
    <p align="center">
        <img alt="logo" src=".github/assets/logo.png" width="400">
    </p>
</div>

# Fact

A file system based event store.

## Features

- Traditional event sourcing capabilities:
    - Append events to stream
    - Read events from stream
    - Read events from store (i.e. all)
    - Subscribe to event stream
    - Subscribe to store
- Compliant with the [Dynamic Consistency Boundary specification](https://dcb.events/specification/)
    - Append events using a **fail_if_match** query and optional **after_position**
    - Read events using a query
- Just-in-time indexing for event data queries.
- Supports multiple instances for siloed isolation in multi-tenancy setups
- Configurable [Content-Addressable Storage (CAS)](https://en.wikipedia.org/wiki/Content-addressable_storage)
- Backup store contents to compressed file

## Installation

The package can be installed by adding `fact` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:fact, "~> 0.0.1"}
  ]
end
```

## Basic Usage

```elixir
# Start a database instance
iex> Fact.start_link(:mydb)
{:ok, #PID<0.1042.0>}

# Append an event to a stream
iex> Fact.append_stream(:mydb, %{type: "EventSourcingJourneyStarted"}, "journey-1")
{:ok, 1}

# Read the event stream
iex> Fact.read(:mydb, "journey-1") |> Enum.to_list()
[
  %{
    "event_data" => %{},
    "event_id" => "3bb4808303c847fd9ceb0a1251ef95da",
    "event_tags" => []
    "event_type" => "EventSourcingJourneyStarted",
    "event_metadata" => %{},
    "store_position" => 1,
    "store_timestamp" => 1765039106962264,
    "stream_id" => "journey-1",
    "stream_position" => 1
  }
]
```


