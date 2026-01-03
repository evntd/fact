defmodule Fact.Seam.StorageLayout.Standard.V1 do
  use Fact.Seam.StorageLayout,
    family: :standard,
    version: 1

  import Fact.Seam.Parsers, only: [parse_directory: 1]

  @enforce_keys [:path]
  defstruct [:path]

  @impl true
  def default_options(), do: %{path: nil}

  @impl true
  def option_specs() do
    %{
      path: %{
        allowed: :any,
        parse: &parse_directory/1,
        error: :invalid_path_option
      }
    }
  end

  @impl true
  def path(%__MODULE__{path: path}, _opts), do: path

  @impl true
  def records_path(%__MODULE__{path: path}, _opts), do: Path.join(path, "events")

  @impl true
  def indices_path(%__MODULE__{path: path}, _opts), do: Path.join(path, "indices")

  @impl true
  def ledger_path(%__MODULE__{path: path}, _opts), do: path

  @impl true
  def locks_path(%__MODULE__{path: path}, _opts), do: path
end
