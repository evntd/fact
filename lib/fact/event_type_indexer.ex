defmodule Fact.EventTypeIndexer do
  @moduledoc """
  An event indexer that extracts the type of an event.

  This module implements the `Fact.EventIndexer` behaviour. It returns the value
  stored under the event's type field.

  This indexer is useful for grouping, filtering, or querying events by their
  type within an event store or event-driven system.
  """
  use Fact.EventIndexer

  @doc """
  Retrieves the type of the event.

  ## Parameters

    * `event` — an event.
    * `opts` — indexing options.

  ## Returns

    * the event type if present
    * `nil` if the event has no type field

  ## Examples

      iex> event = %{"type" => "UserCreated"}
      iex> Fact.EventTypeIndexer.index_event(event, [])
      "UserCreated"

      iex> event = %{"type" => "InvoiceSent"}
      iex> Fact.EventTypeIndexer.index_event(event, [])
      "InvoiceSent"
  """
  @impl true
  def index_event(event, _opts), do: event[@event_type]
end
