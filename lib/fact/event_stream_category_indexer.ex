defmodule Fact.EventStreamCategoryIndexer do
  @moduledoc false
  use Fact.EventIndexer, path: :event_stream_category

  @impl true
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
