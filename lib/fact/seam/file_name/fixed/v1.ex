defmodule Fact.Seam.FileName.Fixed.V1 do
  @moduledoc """
  A file name implementation that returns a fixed, preconfigured name.

  This `Fact.Seam.FileName` implementation ignores the value input and always returns
  the fixed `:name` specified in its configuration.
  """
  use Fact.Seam.FileName,
    family: :fixed,
    version: 1

  import Fact.Seam.Parsers, only: [parse_filename: 1]

  @enforce_keys [:name]
  defstruct [:name]

  @impl true
  def default_options(), do: %{name: nil}

  @impl true
  def option_specs() do
    %{
      name: %{
        allowed: :any,
        parse: &parse_filename/1,
        error: :invalid_name_option
      }
    }
  end

  @impl true
  def get(%__MODULE{name: name}, _value, _opts), do: {:ok, name}
end
