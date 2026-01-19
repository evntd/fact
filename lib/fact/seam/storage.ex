defmodule Fact.Seam.Storage do
  @moduledoc """
  Behaviour defining the storage configuration for a Fact database.

  This `Fact.Seam` implementation specifies the **paths** used by the system
  for storing events, indices, ledgers, and locks. Implementations of this
  behaviour allow different storage layouts, file structures, or storage
  backends to be plugged in.

  ## Responsibilities

    * `path/2` – Returns the root path of the database.
    * `records_path/3` – Returns the path where event records are stored, or the path to a specific record.
    * `indices_path/2` – Returns the path where index files are stored.
    * `ledger_path/2` – Returns the path for the event ledger file(s).
    * `locks_path/2` – Returns the path for lock files used for database concurrency.

  Each function receives a configured instance (`t()`) and optional keyword
  arguments, and should return either a valid `Path.t()` or an error tuple.

  This allows the Fact system to operate on different storage strategies
  without changing the core database or event logic.
  """
  @moduledoc since: "0.1.0"

  use Fact.Seam

  @doc """
  A callback function that initializes the directory structure used for records, indexes, 
  and any other files used by the database.
  """
  @doc since: "0.2.0"
  @callback initialize_storage(t(), opts :: keyword()) :: {:ok, Path.t()} | {:error, term()}

  @doc """
  A callback function that gets the path to configured root directory for the database.
  """
  @doc since: "0.1.0"
  @callback path(t(), opts :: keyword()) :: Path.t() | {:error, term()}

  @doc """
  A callback function that gets the directory containing all records, or the path to a specific record.
  """
  @doc since: "0.2.0"
  @callback records_path(t(), record_id :: String.t(), opts :: keyword()) ::
              Path.t() | {:error, term()}

  @doc """
  A callback function that gets the base path to the directory where all index files are stored. 
  """
  @doc since: "0.1.0"
  @callback indices_path(t(), opts :: keyword()) :: Path.t() | {:error, term()}

  @doc """
  A callback function that gets the path to the directory containing the ledger file.
  """
  @doc since: "0.1.0"
  @callback ledger_path(t(), opts :: keyword()) :: Path.t() | {:error, term()}

  @doc """
  A callback function that gets the path to the directory containing the lock files.
  """
  @doc since: "0.1.0"
  @callback locks_path(t(), opts :: keyword()) :: Path.t() | {:error, term()}
end
