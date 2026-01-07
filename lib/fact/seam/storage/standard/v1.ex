defmodule Fact.Seam.Storage.Standard.V1 do
  @moduledoc """
  Standard V1 implementation of the `Fact.Seam.Storage` seam.

  This module provides file-system–based storage paths for a database context. 
  It defines where event records, indices, ledgers, and locks are stored on disk.

  Options:
    * `:path` – the root directory for the database storage. All sub-paths are derived from this.
  """
  use Fact.Seam.Storage,
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
