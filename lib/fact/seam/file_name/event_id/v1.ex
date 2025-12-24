defmodule Fact.Seam.FileName.EventId.V1 do
  use Fact.Seam.FileName,
    family: :event_id,
    version: 1

  use Fact.Types

  defstruct []

  # TODO: This depends on the RecordSchema!
  @impl true
  def for(%__MODULE__{}, event_record) do
    event_record[@event_id]
  end
end
