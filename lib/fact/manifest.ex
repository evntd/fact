defmodule Fact.DatabaseError do
  defexception [:message]
end

defmodule Fact.Manifest do
  @moduledoc false

  require Logger

  @manifest_filename "manifest.json"

  @record_filename_schemes %{
    "id" => Fact.Storage.Driver.ByEventId,
    "cas" => Fact.Storage.Driver.ContentAddressable
  }

  @record_file_format %{
    "json" => Fact.Storage.Format.Json
  }

  @indexer_modules %{
    "event_type" => Fact.EventTypeIndexer,
    "event_tags" => Fact.EventTagsIndexer,
    "event_stream" => Fact.EventStreamIndexer,
    "event_stream_category" => Fact.EventStreamCategoryIndexer,
    "event_streams" => Fact.EventStreamsIndexer,
    "event_streams_by_category" => Fact.EventStreamsByCategoryIndexer
  }

  def load!(path) when is_binary(path) do
    abspath = Path.absname(path)

    manifest_path =
      if File.dir?(abspath), do: Path.join(abspath, @manifest_filename), else: abspath

    base_dir = Path.dirname(manifest_path)

    unless Path.basename(manifest_path) === @manifest_filename do
      raise Fact.DatabaseError,
        message: """
        Invalid Fact database manifest: #{manifest_path}
        """
    end

    unless File.exists?(manifest_path) do
      suggested_name = base_dir |> Path.basename()

      raise Fact.DatabaseError,
        message: """
        No Fact database exists at: #{base_dir}

        Use "mix fact.create --name #{suggested_name}" to create one. 
        """
    end

    manifest_json = File.read!(manifest_path)
    manifest = Fact.Json.decode!(manifest_json)

    load!(base_dir, manifest)
  end

  def load!(path, %{"manifest_version" => "0.1.0"} = manifest) when is_binary(path) do
    # Let's just assume everything is correct at the moment.

    config =
      %{
        manifest_version: Version.parse!(manifest["manifest_version"]),
        engine_version: Version.parse!(manifest["engine_version"]),
        schema_version: Version.parse!(manifest["schema_version"]),
        storage_version: Version.parse!(manifest["storage_version"]),
        database_id: manifest["database_id"],
        database_name: manifest["database_name"],
        database_path: path,
        events_path: Path.join(path, "events"),
        indices_path: Path.join(path, "indices"),
        ledger_path: Path.join(path, ".ledger"),
        records: %{
          file_format: String.to_atom(manifest["records"]["file_format"]),
          filename_scheme: String.to_atom(manifest["records"]["filename_scheme"]),
          old_format: @record_file_format[manifest["records"]["file_format"]],
          old_driver: @record_filename_schemes[manifest["records"]["filename_scheme"]]
        },
        indexers:
          Enum.map(manifest["indexers"], fn indexer ->
            module = @indexer_modules[indexer["name"]]

            old_encoding =
              if indexer["filename_scheme"] === "raw",
                do: :raw,
                else: {:hash, indexer["hash_algorithm"]}

            %{
              module: module,
              name: String.to_atom(indexer["name"]),
              filename_scheme: String.to_atom(indexer["filename_scheme"]),
              hash_algorithm: indexer["hash_algorithm"],
              hash_encoding: indexer["hash_encoding"],
              old_spec:
                {@indexer_modules[indexer["name"]], [enabled: true, encoding: old_encoding]},
              old_path: Path.join([path, "indices", to_string(module)])
            }
          end)
      }

    config
  end

  def load!(_path, %{} = _manifest) do
    raise Fact.DatabaseError,
      message: """
      Unsupported database manifest format.
      """
  end
end
