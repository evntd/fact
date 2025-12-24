defmodule Fact.Seam.FileContent.Delimited.V1 do
  use Fact.Seam.FileContent,
    family: :delimited,
    version: 1

  @enforce_keys [:delimiter]
  defstruct [:delimiter]

  @impl true
  def default_options(), do: %{delimiter: "\n"}

  @impl true
  def init(%{} = options), do: struct(__MODULE__, options)

  @impl true
  def normalize_options(%{} = _options), do: {:ok, %{}}

  @impl true
  def can_decode?(%__MODULE__{}), do: false

  @impl true
  def can_decode?(%__MODULE__{}, _binary), do: false

  @impl true
  def can_encode?(%__MODULE__{}), do: true

  @impl true
  def can_encode?(%__MODULE__{}, content) when is_binary(content), do: true
  def can_encode?(%__MODULE__{}, content) when is_list(content), do: true
  def can_encode?(%__MODULE__{}, _content), do: false

  @impl true
  def decode(%__MODULE__{}, _binary), do: {:error, :unsupported_capability}

  @impl true
  def encode(%__MODULE__{delimiter: delimiter}, content) when is_list(content) do
    [Enum.intersperse(content, delimiter), delimiter]
  end
end
