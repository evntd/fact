defmodule Fact.Seam.Decoder.Delimited.V1 do
  use Fact.Seam.Decoder,
    family: :delimited,
    version: 1

  @enforce_keys [:delimiter]
  defstruct [:delimiter]

  @impl true
  def default_options(), do: %{delimiter: "\n"}

  @impl true
  def init(%{} = options), do: struct(__MODULE__, options)

  @impl true
  def normalize_options(%{} = _options), do: %{}

  @impl true
  def decode(%__MODULE__{delimiter: delimiter}, binary) when is_binary(binary) do
    String.split(binary, delimiter)
  end
end
