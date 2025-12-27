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
  def decode(%__MODULE__{delimiter: delimiter}, value) when is_binary(value) do
    {:ok, String.split(value, delimiter)}
  end

  def decode(%__MODULE__{}, value), do: {:error, {:decode, value}}
end
