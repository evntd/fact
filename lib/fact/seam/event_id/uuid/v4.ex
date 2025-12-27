defmodule Fact.Seam.EventId.Uuid.V4 do
  use Fact.Seam.EventId,
    family: :uuid,
    version: 4

  defstruct [:length]

  @impl true
  def init(_options) do
    with state <- struct(__MODULE__, %{}),
         {:ok, uuid} <- generate(state) do
      %{state | length: String.length(uuid)}
    end
  end

  @impl true
  def generate(%__MODULE__{}) do
    {:ok, get_v4()}
  end

  defp get_v4() do
    :uuid.get_v4()
    |> :uuid.uuid_to_string(:nodash)
    |> to_string()
  end
end
