defmodule Fact.Seam.Storage.Standard.V2 do
  @moduledoc """
  Standard V2 implementation of the `Fact.Seam.Storage` seam.
    
  This module creates 0 to 3 character buckets (i.e. sub-directories) for events.
  Directories with a large number of files can cause performance and operational issues.
    
  Most filesystems store directory entries in data structures (like B-trees or linear lists) that
  degrade as the entry count grows. Listing, searching, or opening files requires scanning or  
  traversing these structures, which becomes slower as directories grow into thousands or millions of files.

  ### Tool Limitations
    
  Many common tools struggle with huge directories.
    
    * Shell glob expansion can exceed argument length limes or consume excessive memory
    * `ls` becomes slow and unwieldy
    * File browsers may hang or become unresponsive
    * Backup tools and file synchronization can slow dramatically

  ### Inode and Metadata Overhead
    
  Directory metadata must often be read into memory. A directory with millions of entries can
  consume significant memory just for the directory itself, separate from the files it contains.
    
  ### Bucket Configurations

  This implementation will create a sub-directory within the base `records_path`. The default event
  record encoding is base16, with a default bucket_length of 2, which would result in 256 "buckets" 
  directories for storing events `00` to `ff`. Using an alternate encoding for record file names or
  increasing the bucket length will increase this. 
    
    |encoding| bucket_length: 1| bucket_length: 2| bucket_length: 3|
    |--|--|--|--|
    |base16|16|256|1,024|
    |base32|32|1,024|32,768|
    |base64url|64|4,096|262,144|

  > #### Too many buckets {: .warning}
  >
  > Having too many buckets is also not good, I would recommend not exceeding 4,096.
  > Configure the system accordingly.
  >

  > #### Future {: .info}
  >
  > A future storage implementation, may add support for nested buckets.

  """
  use Fact.Seam.Storage,
    family: :standard,
    version: 2

  import Fact.Seam.Parsers, only: [parse_directory: 1, parse_integer_range: 3]

  @typedoc """
  The configuration options for the Standard v2 storage seam impl.

    * `:path` - The base path to the database directory.
    * `:bucket_length` - The length of event bucket directories.  
  """
  @typedoc since: "0.2.0"
  @type t :: %__MODULE__{
          path: Path.t(),
          bucket_length: non_neg_integer()
        }

  @enforce_keys [:path]
  defstruct [:path, :bucket_length]

  @doc """
  Get the default configuration options.
  """
  @doc since: "0.2.0"
  @spec default_options() :: t()
  @impl true
  def default_options(), do: %{path: nil, bucket_length: 2}

  @doc """
  Gets the specification for the configuration options.
  """
  @doc since: "0.2.0"
  @impl true
  def option_specs() do
    %{
      path: %{
        allowed: :any,
        parse: &parse_directory/1,
        error: :invalid_path_option
      },
      bucket_length: %{
        allowed: :any,
        parse: fn value -> parse_integer_range(value, 0, 3) end,
        error: :invalid_bucket_length
      }
    }
  end

  @doc """
  Creates the directory structure used for events and indexes.
  """
  @doc since: "0.2.0"
  @spec initialize_storage(t(), keyword()) :: {:ok, Path.t()} | {:error, term()}
  @impl true
  def initialize_storage(%__MODULE__{path: path} = this, opts) do
    with :ok <- File.mkdir_p(path),
         :ok <- File.mkdir_p(records_path(this, nil, opts)),
         :ok <- File.mkdir_p(indices_path(this, opts)),
         :ok <- File.write(Path.join(path, ".gitignore"), "*") do
      {:ok, path}
    end
  end

  @doc """
  Gets the configured base path for the database.
  """
  @doc since: "0.2.0"
  @spec path(t(), keyword()) :: Path.t()
  @impl true
  def path(%__MODULE__{path: path}, _opts), do: path

  @doc """
  Gets the path to the base directory for records, or the path to a specific record.
  """
  @doc since: "0.2.0"
  @spec records_path(t(), nil | Fact.record_id(), keyword()) :: Path.t()
  @impl true
  def records_path(%__MODULE__{path: path, bucket_length: _}, nil, _opts) do
    Path.join(path, "events")
  end

  def records_path(%__MODULE__{path: path, bucket_length: bucket_length}, record_id, _opts)
      when is_binary(record_id) do
    bucket = String.slice(record_id, 0, bucket_length)
    bucket_path = Path.join([path, "events", bucket])
    unless File.exists?(bucket_path), do: File.mkdir(bucket_path)
    Path.join(bucket_path, record_id)
  end

  @doc """
  Gets the path to the base directory for all indexes.
  """
  @doc since: "0.2.0"
  @spec indices_path(t(), keyword()) :: Path.t()
  @impl true
  def indices_path(%__MODULE__{path: path}, _opts), do: Path.join(path, "indices")

  @doc """
  Gets the path to the directory containing the ledger. 
  """
  @doc since: "0.2.0"
  @spec ledger_path(t(), keyword()) :: Path.t()
  @impl true
  def ledger_path(%__MODULE__{path: path}, _opts), do: path

  @doc """
  Gets the path to the directory containing the lock file. 
  """
  @doc since: "0.2.0"
  @spec locks_path(t(), keyword()) :: Path.t()
  @impl true
  def locks_path(%__MODULE__{path: path}, _opts), do: path
end
