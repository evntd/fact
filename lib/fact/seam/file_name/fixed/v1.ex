defmodule Fact.Seam.FileName.Fixed.V1 do
  use Fact.Seam.FileName,
    family: :fixed,
    version: 1

  @type filename() :: String.t()

  @type t :: %{required(:name) => filename()}

  @type reason ::
          {:invalid_name_option, term()}
          | {:unknown_option, term()}

  @enforce_keys [:name]
  defstruct [:name]

  @option_specs %{
    name: %{
      allowed: :any,
      parse: &__MODULE__.parse_filename/1,
      error: :invalid_name_option
    }
  }

  @impl true
  def get(%__MODULE{name: name}, _value, _opts), do: name

  @impl true
  @spec init(map()) :: t() | {:error, reason()}
  def init(options) when is_map(options) do
    default_options()
    |> Map.merge(options)
    |> validate_options(@option_specs)
    |> case do
      {:ok, valid} ->
        struct(__MODULE__, valid)

      {:error, _} = error ->
        error
    end
  end

  @impl true
  @spec normalize_options(%{atom() => String.t()}) :: map() | {:error, reason()}
  def normalize_options(%{} = options) do
    options
    |> Map.take(Map.keys(@option_specs))
    |> validate_options(@option_specs)
    |> case do
      {:ok, valid} ->
        valid

      {:error, _} = error ->
        error
    end
  end

  defp validate_options(options, specs) when is_map(options) do
    Enum.reduce_while(options, {:ok, %{}}, fn {key, value}, {:ok, acc} ->
      case Map.fetch(specs, key) do
        :error ->
          {:halt, {:error, {:unknown_option, key}}}

        {:ok, %{parse: parse, allowed: allowed, error: error}} ->
          case parse.(value) do
            {:ok, parsed} ->
              cond do
                allowed == :any ->
                  {:cont, {:ok, Map.put(acc, key, parsed)}}

                parsed in allowed ->
                  {:cont, {:ok, Map.put(acc, key, parsed)}}

                true ->
                  {:halt, {:error, {error, value}}}
              end

            _ ->
              {:halt, {:error, {error, value}}}
          end
      end
    end)
  end

  # Simple filenames...for compatibility.
  # - Alpha-numeric
  # - Dots, dashes, and underscores
  # - NO SPACES! They always become a PITA at some point.
  @filename_regex ~r/^[A-Za-z0-9._-]+$/

  def parse_filename(value) when is_binary(value) do
    # Reject anything that includes directory components
    if value == Path.basename(value) and Regex.match?(@filename_regex, value) do
      {:ok, value}
    else
      :error
    end
  end
end
