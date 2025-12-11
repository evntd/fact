defmodule Fact.EventStreamCategoryIndexer do
  @moduledoc """
  Indexes events by the *category* portion of an event stream, by splitting the string on a 
  specified separator (default :`"-"`) and returns the first segment.
  """
  use Fact.EventIndexer

  @default_separator "-"

  @doc """
  Extracts a category from an event stream id.

  ## Options

    * `:separator` - optional delimiter used to split the stream name.
        Defaults to `"-"`.

  ## Examples

      iex> event = %{"event_type" => "TestEvent", "stream_id" => "user-123"}
      iex> Fact.EventStreamCategoryIndexer.index_event(event, [])
      "user"

      iex> event = %{"event_type" => "TestEvent", "stream_id" => "order:987"}
      iex> Fact.EventStreamCategoryIndexer.index_event(event, separator: ":")
      "order"

      iex> event = %{"event_type" => "TestEvent"}
      iex> Fact.EventStreamCategoryIndexer.index_event(event, [])
      nil

  """
  @impl true
  def index_event(%{@event_stream => stream}, opts) do
    separator = Keyword.get(opts, :separator, @default_separator)
    stream |> String.split(separator, parts: 2) |> List.first()
  end

  def index_event(_event, _opts), do: nil
end
