defmodule Fact.EventTagsIndexer do
  @moduledoc false
  use Fact.EventIndexer, path: :event_tags

  @impl true
  def index_event(%{@event_tags => tags}, _opts), do: tags
  def index_event(_event, _opts), do: nil
end
