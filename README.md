[![Test](https://github.com/evntd/fact/actions/workflows/elixir.yml/badge.svg)](https://github.com/evntd/fact/actions/workflows/elixir.yml)

<div style="display: flex; justify-content: center;">
  <img alt="logo" src=".github/assets/logo.png" width="424">
</div>

## About

*Fact* is an **Elixir library** that provides a file system based event store database.

## Features

- Traditional event sourcing capabilities:
    - Append events to event streams
    - Read events from specific event streams or all events in the event store
    - Subscribe to specific event streams or all events in the event store
    - [Optimistic concurrency control](https://en.wikipedia.org/wiki/Optimistic_concurrency_control)
- Compliant with the [Dynamic Consistency Boundary specification](https://dcb.events/specification/)
- Just-in-time indexing for event data queries.
- Supports multiple instances for siloed isolation in multi-tenancy setups
- Configurable [Content-Addressable Storage (CAS)](https://en.wikipedia.org/wiki/Content-addressable_storage)
- Backup store contents to compressed file
- Supported on Elixir 1.13+ and OTP 25+

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

