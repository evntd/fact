defmodule Mix.Tasks.Fact.Create do
  @moduledoc """
  Creates a new database.

  This task initializes a database directory with a `manifest.json`, `.ledger`, `.gitignore`, and `events` and `indices`
  directories. It also creates a subdirectory within `indices` and a `.checkpoint` file for each enabled indexer.

  ## Usage
    
  ```sh
  mix fact.create --name|-n NAME \\
    [--path|-p PATH] \\
    [--record-file-format json] \\
    [--record-filename-scheme RECORD_SCHEME] \\
    [--cas-hash-algorithm HASH_ALGORITHM] \\
    [--cas-hash-encoding ENCODING] \\
    [--all-indexers] \\
    [--index-filename-scheme INDEX_SCHEME] \\
    [--index-hash-algorithm HASH_ALGORITHM] \\
    [--index-hash-encoding ENCODING] \\
    [--indexer|-i INDEXER] \\
    [--indexer-option|-x INDEXER:INDEX_OPTION=VALUE]
  ```

  By default, the database will be created in a directory matching
  the database name.

  ## Options

    * `--name`, `-n` - Database name (lowercase, alphanumeric, hyphens, maximum of 63 characters)
    * `--path`, `-p` - Target directory (defaults to the database name in the current working directory)
    * `--record-file-format` - Record serialization format (default: `json`)
    * `--record-filename-scheme` - Determines the filenames of written event records (default: `id`)

  ### Content addressable storage (CAS)

  When `--record-filename-scheme` is set to `cas`, the following options control, how event record ids are produced and
  written to disk.
    
    * `--cas-hash-algorithm` - The algorithm used to hash the contents of written events (default: `blake2b`)
    * `--cas-hash-encoding` - Controls how the hashes are encoded (default: `url_encode64`)
   
  ### Indexing
    
    * `--all-indexers` - Enables all supported indexers
    * `--indexer`, `-i` - Enables a specific indexer  
    * `--index-filename-scheme` - Controls how index files are named (default: `raw`)
    * `--index-hash-algorithm` - The algorithm used to hash index files (default: `sha`)
    * `--index-hash-encoding` - Controls how the hashes are encoded (default: `encode16`)
    * `--indexer-option`, `-x` - Overrides the filename-scheme, hash algorithm, or hash encoding on a per-indexer basis.  

  Individual settings may be overridden on a per-indexer basis using the `--indexer-option`. 
  The specified value must conform to the following format: `<indexer>:<option>=<value>`
    
  Valid options are `filename_scheme`, `hash_algorithm`, `hash_encoding`.  

  ```sh
  --indexer-option event_type:filename_scheme=hash
  --indexer-option event_type:hash_algorithm=sha256
  --indexer-option event_tags:hash_encoding=encode32
  ```
    
  #### Indexers
    
    * `event_type` - See `Fact.EventTypeIndexer`
    * `event_tags` - See `Fact.EventTagsIndexer`
    * `event_stream` - See `Fact.EventStreamIndexer`
    * `event_data` - See `Fact.EventDataIndexer`
    * `event_stream_category` - See `Fact.EventStreamCategoryIndexer`
    * `event_streams` - See `Fact.EventStreamsIndexer`
    * `event_streams_by_category` - See `Fact.EventStreamsByCategoryIndexer`

  #### Record Filename Schemes
    
    * `id` - Each event record is written with a filename that matches the event id, which is a UUID v4 encoded in 
    lowercase base-16. 

    * `cas` - Each event record is written with a filename that is a hash of the event contents. This can be used to check
    for external tampering. When using CAS, the hash algorithm (default `blake2b`) and encoding (default `url_encode64`) 
    can be configured.

  #### Index Filename Schemes
    
    * `raw` - Each index file uses the value that was matched within the event.

    * `hash` - Index files use the hash of the value that was matched within the event. This is primarily used to
    ensure safe file names, this is not an attempt at security by obscurity.
    
  #### Hash Algorithms

  Any of the following hash algorithms can be used for `--cas-hash-algorithm`, `--index-hash-algorithm`, or indexer 
  specific overrides. 
    
    * `md5` - Only for `--index-hash-algorithm`
    * `sha` - Only for `--index-hash-algorithm`
    * `sha256`
    * `sha512`
    * `sha3_256`
    * `sha3_512`
    * `blake2b`
    * `blake2s`

  #### Encoding options
    
  Any of the following encodings can be used for `--cas-hash-encoding`, `--index-hash-encoding`, or indexer specific 
  overrides. These options all produce strings which are safe to use for filenames.
    
    * `encode16` - Base 16 encoded, lowercase.
    * `encode32` - Base 32 encoded, with padding trimmed.
    * `url_encode64` - Base 64 encoded, with padding trimmed.

  ## Examples

  Create a simple database:

      mix fact.create --name example

  Create a database using CAS and with hashed indexes:

  ```sh  
  mix fact.create \\
    --name example \\
    --record-filename-scheme cas \\
    --cas-hash-algorithm blake2b \\
    --index-filename-scheme hash
  ```

  Create a database with a per-index override:

  ```sh
  mix fact.create \\
    --name example \\
    --indexer event_type \\
    --indexer-option event_type:filename_scheme=hash \\
    --indexer-option event_type:hash_algorithm=sha256  
  ```
  """

  use Mix.Task

  @switches [
    name: :string,
    path: :string,
    record_file_format: :string,
    record_filename_scheme: :string,
    cas_hash_algorithm: :string,
    cas_hash_encoding: :string,
    index_filename_scheme: :string,
    index_hash_algorithm: :string,
    index_hash_encoding: :string,
    indexer: :keep,
    indexer_option: :keep,
    all_indexers: :boolean,
    quiet: :boolean
  ]

  @aliases [
    n: :name,
    p: :path,
    i: :indexer,
    x: :indexer_option,
    q: :quiet
  ]

  @impl true
  def run(args) do
    {parsed, _argv} = OptionParser.parse!(args, strict: @switches, aliases: @aliases)

    quiet = Keyword.get(parsed, :quiet, false)

    unless quiet, do: display_banner()

    name = get_name(parsed)
    path = get_path(parsed, name)
    manifest = create_manifest_v1(name, parsed)

    File.mkdir_p!(path)
    File.write!(Path.join(path, "manifest"), Fact.Json.encode!(manifest))
    File.mkdir!(Path.join(path, "events"))
    File.touch!(Path.join(path, ".ledger"))
    File.write!(Path.join(path, ".gitignore"), "*")

    indices_path = Path.join(path, "indices")
    File.mkdir!(indices_path)

    manifest.indexers
    |> Enum.each(fn indexer ->
      index_path = Path.join(indices_path, indexer.name)
      File.mkdir!(index_path)
    end)

    unless quiet do
      display_results(path, manifest)
      display_next_steps()
    end
  end

  defp display_banner() do
    # ANSI Shadow
    Mix.shell().info("""


          ███████╗ █████╗  ██████╗ ████████╗
          ██╔════╝██╔══██╗██╔════╝ ╚══██╔══╝
          █████╗  ███████║██║         ██║   
          ██╔══╝  ██╔══██║██║         ██║   
          ██║     ██║  ██║╚██████╗    ██║   
       🐢 ╚═╝     ╚═╝  ╚═╝ ╚═════╝    ╚═╝ v#{Fact.MixProject.project()[:version]} (#{Fact.MixProject.project()[:codename]})  

    """)
  end

  defp display_results(path, manifest) do
    Mix.shell().info("""
        Database created, you're ready to rock!!! 🤘

      ==============================================================================  
          ID: #{manifest.database_id}
        NAME: #{manifest.database_name}
        PATH: #{path}
      ==============================================================================    
    """)
  end

  defp display_next_steps() do
    Mix.shell().info("""
        Next Steps:
        
          📖 \e]8;;#{Fact.MixProject.project()[:docs][:canonical]}\e\\Read the documentation\e]8;;\e\\ at #{Fact.MixProject.project()[:docs][:canonical]}
          🤓 \e]8;;https://leanpub.com/eventmodeling-and-eventsourcing\e\\Learn to understand event sourcing\e]8;;\e\\ 
          🍺 \e]8;;https://www.amazon.com/Complete-Joy-Homebrewing-Fourth-Revised/dp/0062215752\e\\Relax, don't worry, have a homebrew\e]8;;\e\\
    """)
  end

  defp get_name(parsed) do
    parsed_name = Keyword.get(parsed, :name)

    unless parsed_name do
      Mix.raise("""
      Missing database name, use "mix fact.create --name <name>"
      """)
    end

    name = normalize_name(parsed_name)
    :ok = validate_name(name)
    name
  end

  defp normalize_name(name), do: String.trim(name)

  defp validate_name(name) do
    if String.length(name) > 63 do
      Mix.raise("""
      Invalid database name, it may only be up to 63 characters in length.
      """)
    end

    unless String.match?(name, ~r/^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$/) do
      Mix.raise(
        "Invalid database name, it may only contain the characters a-z, 0-9, and - (hyphen)."
      )
    end

    :ok
  end

  defp get_path(parsed, default) do
    parsed_path = Keyword.get(parsed, :path, default)
    path = normalize_path(parsed_path)
    :ok = validate_path(path)
    path
  end

  defp validate_path(path) do
    # Verify the supplied path does not already exist
    if File.exists?(path) do
      if not File.dir?(path) do
        Mix.raise("""
        Requires the path to be a directory, a file was specified: #{path}
        """)
      end

      if File.ls!(path) != [] do
        Mix.raise("""
        Requires the path to not exist or be empty: #{path}
        """)
      end
    end

    :ok
  end

  defp normalize_path(path), do: String.trim(path) |> Path.expand()

  @manifest_version "0.1.0"
  @record_version "0.1.0"
  @index_version "0.1.0"
  @storage_version "0.1.0"

  defp create_manifest_v1(name, parsed) do
    %{
      os_version: os_version(),
      otp_version: :erlang.system_info(:otp_release) |> to_string(),
      elixir_version: System.version(),
      manifest_version: @manifest_version,
      engine_version: Fact.MixProject.project()[:version],
      storage_version: @storage_version,
      record_version: @record_version,
      index_version: @index_version,
      database_id: generate_id(),
      database_name: name,
      created_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      records: get_records_options(parsed),
      indexers: get_indexers(parsed)
    }
  end

  defp generate_id() do
    :uuid.get_v4() |> Base.encode32(padding: false)
  end

  defp os_version() do
    {_os_family, os_name} = :os.type()

    os_version =
      case :os.version() do
        {major, minor, release} ->
          "#{major}.#{minor}.#{release}"
        version_string ->
          version_string
      end

    "#{os_name} #{os_version}"
  end

  defp get_records_options(parsed) do
    record_filename_scheme = get_record_filename_scheme(parsed)

    %{
      file_format: get_record_file_format(parsed),
      filename_scheme: record_filename_scheme
    }
    |> Map.merge(
      if record_filename_scheme === "cas",
        do: %{content_addressable_storage: get_cas_options(parsed)},
        else: %{}
    )
  end

  @valid_record_filename_schemes ["id", "cas"]
  @default_record_filename_scheme "id"

  defp get_record_filename_scheme(parsed) do
    record_filename_scheme =
      Keyword.get(parsed, :record_filename_scheme, @default_record_filename_scheme)
      |> normalize_string()

    :ok =
      validate_option(
        "record filename scheme",
        @valid_record_filename_schemes,
        record_filename_scheme
      )

    record_filename_scheme
  end

  defp normalize_string(value), do: String.trim(value) |> String.downcase()

  defp validate_option(title, options, value) do
    cond do
      value in options ->
        :ok

      true ->
        Mix.raise("""
        Invalid #{title} "#{value}", use one of these: #{inspect(options)}
        """)
    end
  end

  @valid_record_file_formats ["json"]
  @default_record_file_format "json"

  defp get_record_file_format(parsed) do
    record_file_format =
      Keyword.get(parsed, :record_file_format, @default_record_file_format)
      |> normalize_string()

    :ok =
      validate_option("record file format", @valid_record_file_formats, record_file_format)

    record_file_format
  end

  defp get_cas_options(parsed) do
    %{
      hash_algorithm: get_cas_hash_algorithm(parsed),
      hash_encoding: get_cas_hash_encoding(parsed)
    }
  end

  @valid_cas_hash_algorithms ["sha256", "sha512", "sha3_256", "sha3_512", "blake2b", "blake2s"]
  @default_cas_hash_algorithm "sha256"

  defp get_cas_hash_algorithm(parsed) do
    cas_hash_algorithm =
      Keyword.get(parsed, :cas_hash_algorithm, @default_cas_hash_algorithm)
      |> normalize_string()

    :ok =
      validate_option(
        "content addressable storage algorithm",
        @valid_cas_hash_algorithms,
        cas_hash_algorithm
      )

    cas_hash_algorithm
  end

  @valid_cas_hash_encodings ["encode16", "encode32", "url_encode64"]
  @default_cas_hash_encoding "url_encode64"

  defp get_cas_hash_encoding(parsed) do
    cas_hash_encoding =
      Keyword.get(parsed, :cas_hash_encoding, @default_cas_hash_encoding)
      |> normalize_string()

    :ok =
      validate_option(
        "content addressable storage encoding",
        @valid_cas_hash_encodings,
        cas_hash_encoding
      )

    cas_hash_encoding
  end

  @valid_indexers [
    "event_data",
    "event_stream",
    "event_stream_category",
    "event_streams",
    "event_streams_by_category",
    "event_tags",
    "event_type"
  ]
  @required_indexers ["event_data", "event_stream", "event_tags", "event_type"]

  defp get_indexers(parsed) do
    get_indexers(parsed, get_default_indexer_options(parsed))
  end

  defp get_indexers(parsed, default_indexer_options) do
    indexer_options = get_indexer_options(parsed)

    indexer_list =
      if Keyword.get(parsed, :all_indexers) do
        @valid_indexers
      else
        Keyword.get_values(parsed, :indexer)
        |> Enum.map(&normalize_string/1)
        |> Enum.concat(@required_indexers)
        |> Enum.uniq()
      end

    :ok = validate_indexers(indexer_list)

    indexer_list
    |> Enum.map(fn indexer ->
      override_indexer_options =
        Map.merge(
          %{name: indexer},
          Map.new(
            indexer_options
            |> Enum.filter(fn {i, _, _} -> i === indexer end)
            |> Enum.map(fn {_, k, v} -> {String.to_atom(k), v} end)
          )
        )

      usable_default_indexer_options =
        case {override_indexer_options[:filename_scheme],
              default_indexer_options[:filename_scheme]} do
          {nil, "raw"} ->
            Map.take(default_indexer_options, [:filename_scheme])

          {"hash", "raw"} ->
            Map.take(default_indexer_options, [:hash_algorithm, :hash_encoding])

          {"raw", _} ->
            %{}

          {_, "hash"} ->
            default_indexer_options
        end

      Map.merge(usable_default_indexer_options, override_indexer_options)
    end)
  end

  defp get_default_indexer_options(parsed) do
    %{
      filename_scheme: get_index_filename_scheme(parsed),
      hash_algorithm: get_index_hash_algorithm(parsed),
      hash_encoding: get_index_hash_encoding(parsed)
    }
  end

  @valid_index_filename_schemes ["raw", "hash"]
  @default_index_filename_scheme "raw"

  defp get_index_filename_scheme(parsed) do
    index_filename_scheme =
      Keyword.get(parsed, :index_filename_scheme, @default_index_filename_scheme)
      |> normalize_string()

    :ok =
      validate_option(
        "index filename scheme",
        @valid_index_filename_schemes,
        index_filename_scheme
      )

    index_filename_scheme
  end

  @valid_index_hash_algorithms [
    "sha",
    "md5",
    "sha256",
    "sha512",
    "sha3_256",
    "sha3_512",
    "blake2b",
    "blake2s"
  ]
  @default_index_hash_algorithm "sha"

  defp get_index_hash_algorithm(parsed) do
    index_hash_algorithm =
      Keyword.get(parsed, :index_hash_algorithm, @default_index_hash_algorithm)
      |> normalize_string()

    :ok =
      validate_option(
        "index hash algorithm",
        @valid_index_hash_algorithms,
        index_hash_algorithm
      )

    index_hash_algorithm
  end

  @valid_index_hash_encodings ["encode16", "encode32", "url_encode64"]
  @default_index_hash_encoding "encode16"

  defp get_index_hash_encoding(parsed) do
    index_hash_encoding =
      Keyword.get(parsed, :index_hash_encoding, @default_index_hash_encoding)
      |> normalize_string()

    :ok =
      validate_option(
        "index hash encoding",
        @valid_index_hash_encodings,
        index_hash_encoding
      )

    index_hash_encoding
  end

  defp get_indexer_options(parsed) do
    indexer_options =
      Keyword.get_values(parsed, :indexer_option)
      |> parse_indexer_options()

    :ok = validate_indexer_options(indexer_options)

    indexer_options
  end

  defp parse_indexer_options(options), do: Enum.map(options, &parse_indexer_option/1)

  defp parse_indexer_option(option) do
    with [indexer, option_part] <- String.split(option, ":", parts: 2),
         [option, value] <- String.split(option_part, "=", parts: 2) do
      {indexer, option, value}
    else
      _ ->
        Mix.raise("""
        Invalid indexer option format, use <indexer>:<option>=value: #{option}
        """)
    end
  end

  @valid_indexer_options ["filename_scheme", "hash_algorithm", "hash_encoding"]

  defp validate_indexer_options(options), do: Enum.each(options, &validate_indexer_option/1)

  defp validate_indexer_option({indexer, option, value}) do
    validate_indexer(indexer)
    validate_option(indexer <> " indexer option", @valid_indexer_options, option)

    cond do
      option === "filename_scheme" ->
        validate_option("#{indexer} #{option} value", @valid_index_filename_schemes, value)

      option === "hash_algorithm" ->
        validate_option("#{indexer} #{option} value", @valid_index_hash_algorithms, value)

      option === "hash_encoding" ->
        validate_option("#{indexer} #{option} value", @valid_index_hash_encodings, value)
    end
  end

  defp validate_indexers(indexers) do
    Enum.each(indexers, &validate_indexer/1)
    :ok
  end

  defp validate_indexer(indexer) do
    validate_option("indexer", @valid_indexers, indexer)
  end
end
