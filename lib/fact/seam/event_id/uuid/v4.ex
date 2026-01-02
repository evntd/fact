defmodule Fact.Seam.EventId.Uuid.V4 do
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
