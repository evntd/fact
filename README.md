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
iex(1)> Fact.start_link(:mydb)
{:ok, #PID<0.1042.0>}

iex(2)> event = %{
...(2)>   type: "EventSourcingJourneyStarted", 
...(2)>   data: %{ 
...(2)>     user_id: System.get_env("USER"), 
...(2)>     started_at: DateTime.utc_now() |> DateTime.to_unix(:millisecond)
...(2)>   }
...(2)> }
%{
  data: %{started_at: 1765038776528, user_id: "jake"},
  type: "EventSourcingJourneyStarted"
}

iex(3)> {:ok, position} = Fact.append_stream(:mydb, event, "esjourney-1")
{:ok, 1}

iex(4)> Fact.read(:mydb, "esjourney-1") |> Enum.to_list()
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


