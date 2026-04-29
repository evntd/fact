defmodule Fact.Seam.Encoder.Delimited.V1 do
  @moduledoc """
  Delimited encoder implementation for event records.

  Transforms a list of values (or a single binary) into a delimited sequence using the 
  configured delimiter. Supports `:lf`, `:crlf`, and `:rs` delimiters. Returns `{:ok, iodata}`.
  """
  use Fact.Seam.Encoder,
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
  def encode(%__MODULE__{delimiter: delimiter}, content, _opts) when is_list(content) do
    {:ok, [Enum.intersperse(content, delimiter), delimiter]}
  end

  def encode(%__MODULE__{} = impl, content, opts) when is_binary(content) do
    encode(impl, [content], opts)
  end
end
