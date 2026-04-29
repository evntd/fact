defmodule Fact.Seam.FileName.EventId.V1 do
  @moduledoc """
  A file name implementation that derives the file name from the `event_id` of a given event.

  This `Fact.Seam.FileName` implementation uses the event schema from the provided context
  to extract the `:event_id` from the event and returns it as the file name.
  """
  use Fact.Seam.FileName,
    family: :event_id,
    version: 1

  alias Fact.Event.Schema

  defstruct []

  @impl true
  def get(%__MODULE__{}, event, opts) do
    context = Keyword.get(opts, :__context__)
    {:ok, event[Schema.get(context).event_id]}
  end
end
