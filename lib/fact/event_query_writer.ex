defmodule Fact.EventQueryWriter do
  @moduledoc false

  require Logger

  def append(events, event_query, opts \\ []) do
    {call_opts, append_opts} = Keyword.split(opts, [:timeout])

    Logger.debug(
      "EventQueryWriter call_ops: #{inspect(call_opts)}, append_opts: #{inspect(append_opts)}"
    )

    expected_pos =
      case Keyword.get(append_opts, :expect, :none) do
        :none -> 0
        pos when is_integer(pos) -> pos
      end

    Fact.EventLedger.commit(
      events,
      Keyword.put(call_opts, :condition, {event_query, expected_pos})
    )
  end
end
