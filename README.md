[![Test](https://github.com/evntd/fact/actions/workflows/elixir.yml/badge.svg)](https://github.com/evntd/fact/actions/workflows/elixir.yml)

<div>
    <p align="center">
        <img alt="logo" src=".github/assets/logo.png" width="400">
    </p>
</div>

# Fact

A file system based event store.

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


