defmodule Fact.FileNameFormat.Raw.V1 do
  @behaviour Fact.FileNameFormat

  @type t :: %__MODULE__{}

  @type reason() :: {:unknown_option, term()}

  defstruct []

  @impl true
  @spec id() :: :raw
  def id(), do: :raw

  @impl true
  @spec version() :: 1
  def version(), do: 1

  @impl true
  @spec metadata() :: %{}
  def metadata(), do: %{}

  @impl true
  @spec init(map) :: t() | {:error, reason()}
  def init(metadata) do
    if map_size(metadata) == 0 do
      struct(__MODULE__, %{})
    else
      {:error, {:unknown_option, metadata}}
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
  def for(%__MODULE{} = _format, index_value), do: index_value
end
