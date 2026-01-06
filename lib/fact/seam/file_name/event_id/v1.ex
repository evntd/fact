defmodule Fact.Seam.FileName.EventId.V1 do
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
