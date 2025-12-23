defmodule Fact.FileNameFormat.Raw.V1 do
  @behaviour Fact.Seam.FileNameFormat

  @type t :: %__MODULE__{}

  @type reason() :: {:unknown_option, term()}

  defstruct []

  @impl true
  @spec family() :: :raw
  def family(), do: :raw

  @impl true
  @spec version() :: 1
  def version(), do: 1

  @impl true
  @spec default_options() :: %{}
  def default_options(), do: %{}

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
  @spec for(t(), Fact.EventIndexer.index_value()) :: Path.t() | {:error, reason()}
  def for(%__MODULE{}, index_value), do: index_value
end
