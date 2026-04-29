defmodule Fact.Seam.EventId.Uuid.V4 do
  @moduledoc """
  `Fact.Seam.EventId` implementation that generates UUID v4 identifiers.

  This module produces unique event IDs using the standard UUID v4 algorithm
  and formats them as a string without dashes.
  """
  use Fact.Seam.EventId,
    family: :uuid,
    version: 4

  defstruct []

  @impl true
  def generate(%__MODULE__{}, _opts) do
    :uuid.get_v4()
    |> :uuid.uuid_to_string(:nodash)
    |> to_string()
  end
end
