defmodule Fact.Seam.Storage.Standard.V1 do
  @moduledoc """
  Standard V1 implementation of the `Fact.Seam.Storage` seam.

  This module provides file-system–based storage paths for a database context. 
  It defines where event records, indices, ledgers, and locks are stored on disk.

  Options:
    * `:path` – the root directory for the database storage. All sub-paths are derived from this.
  """
  @moduledoc since: "0.1.0"
  use Fact.Seam.Storage,
    family: :standard,
    version: 1

  import Fact.Seam.Parsers, only: [parse_directory: 1]

  @typedoc """
  The configuration options for the Standard v1 storage seam impl.
  """
  @type t :: %__MODULE__{
          path: Path.t()
        }

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

  @doc """
  Creates the directory structure used for events and indexes.
  """
  @doc since: "0.2.0"
  @impl true
  @spec initialize_storage(t(), keyword()) :: {:ok, Path.t()} | {:error, term()}
  def initialize_storage(%__MODULE__{path: path} = this, opts) do
    with :ok <- File.mkdir_p(path),
         :ok <- File.mkdir_p(records_path(this, nil, opts)),
         :ok <- File.mkdir_p(indices_path(this, opts)),
         :ok <- File.write(Path.join(path, ".gitignore"), "*") do
      {:ok, path}
    end
  end

  @doc """
  Gets the configured root path for the database.
  """
  @doc since: "0.1.0"
  @spec path(t(), keyword()) :: Path.t()
  @impl true
  def path(%__MODULE__{path: path}, _opts), do: path

  @doc """
  Gets the path to base directory for records, or the path to a specific record.
  """
  @doc since: "0.2.0"
  @spec records_path(t(), nil | Fact.record_id(), keyword()) :: Path.t()
  @impl true
  def records_path(%__MODULE__{path: path}, record_id, _opts),
    do: Path.join([path, "events", record_id || ""])

  @doc """
  Gets the path to the base directory for all indexes.
  """
  @doc since: "0.1.0"
  @spec indices_path(t(), keyword()) :: Path.t()
  @impl true
  def indices_path(%__MODULE__{path: path}, _opts), do: Path.join(path, "indices")

  @doc """
  Gets the path to the directory containing the ledger.
  """
  @doc since: "0.1.0"
  @spec ledger_path(t(), keyword()) :: Path.t()
  @impl true
  def ledger_path(%__MODULE__{path: path}, _opts), do: path

  @doc """
  Gets the path to the directory containing the database lock file.
  """
  @doc since: "0.1.0"
  @spec locks_path(t(), keyword()) :: Path.t()
  @impl true
  def locks_path(%__MODULE__{path: path}, _opts), do: path
end
