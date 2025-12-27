defmodule Fact.Seam.Encoder.Delimited.V1 do
  use Fact.Seam.Encoder,
    family: :delimited,
    version: 1

  @enforce_keys [:delimiter]
  defstruct [:delimiter]

  @impl true
  def default_options(), do: %{delimiter: "\n"}

  @impl true
  def init(%{} = options), do: struct(__MODULE__, options)

  @impl true
  def normalize_options(%{} = options), do: options

  @impl true
  def encode(%__MODULE__{delimiter: delimiter}, content) when is_list(content) do
    [Enum.intersperse(content, delimiter), delimiter]
  end
end
