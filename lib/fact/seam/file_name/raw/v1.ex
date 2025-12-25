defmodule Fact.Seam.FileName.Raw.V1 do
  use Fact.Seam.FileName,
    family: :raw,
    version: 1

  @type t :: %__MODULE__{}

  @type reason() :: {:unknown_option, term()}

  defstruct []

  @impl true
  @spec init(map) :: t() | {:error, reason()}
  def init(options) do
    if map_size(options) == 0 do
      struct(__MODULE__, %{})
    else
      {:error, {:unknown_option, options}}
    end
  end

  @impl true
  @spec normalize_options(%{atom() => String.t() | atom()}) :: t() | {:error, reason()}
  def normalize_options(%{} = options) do
    if map_size(options) == 0 do
      %{}
    else
      {:error, {:unknown_option, options}}
    end
  end

  @impl true
  def get(%__MODULE{}, value), do: value
end
