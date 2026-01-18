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
  def initialize_storage(%__MODULE__{path: path} = this, opts) do
    with :ok <- File.mkdir_p(path),
         :ok <- File.mkdir_p(records_path(this, nil, opts)),
         :ok <- File.mkdir_p(indices_path(this, opts)),
         :ok <- File.write(Path.join(path, ".gitignore"), "*") do
      {:ok, path}
    end
  end

  @impl true
  def path(%__MODULE__{path: path}, _opts), do: path

  @impl true
  def records_path(%__MODULE__{path: path}, record_id, _opts),
    do: Path.join([path, "events", record_id || ""])

  @impl true
  def indices_path(%__MODULE__{path: path}, _opts), do: Path.join(path, "indices")

  @impl true
  def ledger_path(%__MODULE__{path: path}, _opts), do: path

  @impl true
  def locks_path(%__MODULE__{path: path}, _opts), do: path
end
