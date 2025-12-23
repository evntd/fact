defmodule Fact.IndexFileName.Raw.V1 do
  @behaviour Fact.IndexFileName

  defstruct []

  @impl true
  def id(), do: :raw

  @impl true
  def version(), do: 1

  @impl true
  def metadata(), do: %{}

  @impl true
  def init(_metadata), do: %__MODULE__{}

  @impl true
  def normalize_options(%{} = _options), do: %{}

  @impl true
  def filename(_format, index_value), do: index_value
end
