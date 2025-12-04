defmodule Fact.EventStreamCategoryIndexer do
  @moduledoc """
  An event indexer that extracts the *category* portion of an event's stream name.

  This module implements the `Fact.EventIndexer` behaviour and derives an index
  value from the event's stream identifier. It is useful in systems where event
  streams follow a naming convention such as:

      "category-id"
      "user-123"
      "order-987"
      "cart-4567"

  The indexer splits the stream name on a separator (default: `"-"`) and returns
  only the first segment. This allows grouping or querying events by stream
  category rather than by the full stream identifier.

  ## Configuration

  The separator can be overridden via the `:separator` option:

      separator: ":"

  """
  use Fact.EventIndexer

  @impl true
  @doc """
  Extracts the category portion of the event's stream name.

  ## Parameters

    * `event` — an event.
    * `opts` — indexing options.
      * `:separator` — optional delimiter used to split the stream name.
        Defaults to `"-"`.

  ## Returns

    * the category portion of the stream (the first segment before the separator)
    * `nil` if the event has no stream value

  ## Examples

      iex> event = %{"stream" => "user-123"}
      iex> Fact.EventStreamCategoryIndexer.index_event(event, [])
      "user"

      iex> event = %{"stream" => "order:987"}
      iex> Fact.EventStreamCategoryIndexer.index_event(event, separator: ":")
      "order"

      iex> event = %{"stream" => nil}
      iex> Fact.EventStreamCategoryIndexer.index_event(event, [])
      nil

  """
  def index_event(event, opts) do
    separator = Keyword.get(opts, :separator, "-")

    case event[@event_stream] do
      nil ->
        nil

      stream ->
        String.split(stream, separator, parts: 2)
        |> List.first()
    end
  end
end
