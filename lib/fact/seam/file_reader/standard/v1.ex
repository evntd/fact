defmodule Fact.FileReader.Standard.V1 do
  @behaviour Fact.Seam.FileReader

  @impl true
  def family(), do: :standard

  @impl true
  def version(), do: 1

  @impl true
  def default_options(), do: %{}

  @impl true
  def init(%{} = _options), do: struct(__MODULE__, %{})

  @impl true
  def normalize_options(%{} = _options), do: %{}
end
