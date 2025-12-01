defmodule Fact.EventQueryWriter do
  require Logger

  def append(instance, events, event_query, opts \\ []) do
    {call_opts, append_opts} = Keyword.split(opts, [:timeout])

    Logger.debug(
      "EventQueryWriter call_ops: #{inspect(call_opts)}, append_opts: #{inspect(append_opts)}"
    )

    expected_pos =
      case Keyword.get(append_opts, :expect, :none) do
        :none -> 0
        pos when is_integer(pos) -> pos
      end

    commit_opts = Keyword.put(call_opts, :condition, {event_query, expected_pos})

    Fact.EventLedger.commit(instance, events, commit_opts)
  end
end
