defmodule Fact.FileNameFormat.EventId.V1 do
  @behaviour Fact.FileNameFormat
  
  use Fact.Types
  
  defstruct []

  @impl true
  def id(), do: :event_id

  @impl true
  def version(), do: 1

  @impl true
  def metadata(), do: %{}

  @impl true
  def init(_metadata), do: %__MODULE__{}

  @impl true
  def normalize_options(%{} = _options), do: {:ok, %{}}

  @impl true
  def for(_format, event_record) do
    event_record[@event_id]
  end
end
