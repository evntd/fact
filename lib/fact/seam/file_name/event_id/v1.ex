defmodule Fact.Seam.FileName.EventId.V1 do
  use Fact.Seam.FileName,
    family: :event_id,
    version: 1

  alias Fact.RecordFile.Schema

  defstruct []

  @impl true
  def get(%__MODULE__{}, event_record, opts) do
    context = Keyword.get(opts, :__context__)
    Schema.event_id(context, event_record)
  end
end
