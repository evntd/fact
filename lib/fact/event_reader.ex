defmodule Fact.EventReader do
  @moduledoc """
  Provides functions for reading events from a Fact database instance.

  `Fact.EventReader` supports three primary sources of events:

    * `:all` — reads from the global ledger index in event-store order.
    * an event stream — reads events belonging to a specific stream.
    * one or more `%Fact.EventQuery{}` structs — executes the query engine and streams results.

  All read operations return a lazy `Stream` of `{record_id, event_record}` tuples, allowing callers
  to process large event sets efficiently without loading them fully into memory.

  ## Options

  The following options are accepted for all read strategies:
    
    * `:direction` — traversal direction (default: `:forward`)
      * `:forward` — increasing positions
      * `:backward` — decreasing positions

    * `:position` - The position to begin reading relative to the event source.
      * `:start` - begin at the start position.
      * `:end` - begin at the last position.
      * integer - starting position, when reading `:forward` this is exclusive, when reading `:backward`
        it is inclusive.


    * `:count` — maximum number of events to return (default: all)
      * `:all` - read all the events
      * integer - a non-negative value

  The reader validates these options and raises a `Fact.DatabaseError` on invalid values.
  """

  use Fact.Types

  #  @doc """
  #  Reads events from the ledger, index, or the events matching an `EventQuery`.
  #  """
  #  @spec read(
  #          Fact.Types.instance_name(),
  #          :all | {:stream, Fact.Types.event_stream()} | {:query, function} | Fact.Query.t(),
  #          keyword()
  #        ) :: Enumerable.t()
end
