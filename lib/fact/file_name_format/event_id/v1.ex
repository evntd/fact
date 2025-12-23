defmodule Fact.FileNameFormat.EventId.V1 do
  @behaviour Fact.Seam.FileNameFormat

  use Fact.Types

  defstruct []

  @impl true
  def family(), do: :event_id

  @impl true
  def version(), do: 1

  @impl true
  def default_options(), do: %{}

  @impl true
  def init(_options), do: %__MODULE__{}

  @impl true
  def normalize_options(%{} = _options), do: {:ok, %{}}

  @impl true
  def for(%__MODULE__{}, event_record) do
    event_record[@event_id]
  end
end
