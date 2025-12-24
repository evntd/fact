defmodule Fact.Seam.FileWriter.Standard.V1 do
  @behaviour Fact.Seam.FileWriter

  defstruct [:modes, :sync, :worm]

  @impl true
  def family(), do: :standard

  @impl true
  def version(), do: 1

  @impl true
  def default_options(), do: %{modes: [:write, :binary], sync: false, worm: false}

  @impl true
  def init(options), do: struct(__MODULE__, options)

  @impl true
  def normalize_options(_options), do: default_options()

  @impl true
  def open(%__MODULE__{}, _path) do
    {:ok, :handle}
  end

  @impl true
  def write(%__MODULE__{}, _handle, _content) do
    :ok
  end

  @impl true
  def close(%__MODULE__{}, _handle) do
    :ok
  end

  @impl true
  def finalize(%__MODULE__{}, _handle) do
    :ok
  end
end
