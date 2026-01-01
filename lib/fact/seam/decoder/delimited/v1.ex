defmodule Fact.Seam.Decoder.Delimited.V1 do
  use Fact.Seam.Decoder,
    family: :delimited,
    version: 1

  import Fact.Seam.Parsers, only: [parse_existing_atom: 1]

  @enforce_keys [:delimiter]
  defstruct [:delimiter]

  @impl true
  def default_options(), do: %{delimiter: :lf}

  @impl true
  def option_specs() do
    %{
      delimiter: %{
        allowed: [
          :lf,
          :crlf,
          :rs
        ],
        parse: &parse_existing_atom/1,
        error: :invalid_delimiter
      }
    }
  end

  @impl true
  def prepare_options(%{delimiter: delimiter_opt}) do
    delimiter =
      case delimiter_opt do
        :lf -> "\n"
        :crlf -> "\r\n"
        :rs -> <<30>>
      end

    %{delimiter: delimiter}
  end

  @impl true
  def decode(%__MODULE__{delimiter: delimiter}, value, _opts) when is_binary(value) do
    {:ok, String.split(value, delimiter)}
  end

  def decode(%__MODULE__{}, value, _opts), do: {:error, {:decode, value}}
end
