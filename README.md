# Fact

A file system based event store.

[![Test](https://github.com/evntd/fact/actions/workflows/elixir.yml/badge.svg)](https://github.com/evntd/fact/actions/workflows/elixir.yml)

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
iex> Fact.start_link(:mydb)
{:ok, #PID<0.1042.0>}

iex> event = %{
...>   type: "EventSourcingJourneyStarted", 
...>   data: %{ 
...>     user_id: System.get_env("USER"), 
...>     started_at: DateTime.utc_now() |> DateTime.to_unix(:millisecond)
...>   }
...> }
%{
  data: %{started_at: 1765038776528, user_id: "jake"},
  type: "EventSourcingJourneyStarted"
}

iex> {:ok, position} = Fact.append_stream(:mydb, event, "esjourney-1")
{:ok, 1}

iex> Fact.read(:mydb, "esjourney-1") |> Enum.to_list()
[
  %{
    "event_data" => %{"started_at" => 1765038776528, "user_id" => "jake"},
    "event_id" => "3bb4808303c847fd9ceb0a1251ef95da",
    "event_tags" => []
    "event_type" => "EventSourcingJourneyStarted",
    "event_metadata" => %{},
    "store_position" => 1,
    "store_timestamp" => 1765039106962264,
    "stream_id" => "esjourney-1",
    "stream_position" => 1
  }
]
```


