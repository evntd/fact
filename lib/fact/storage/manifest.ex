defmodule Fact.Storage.Manifest do
  require Logger

  @manifest_filename "manifest"

  @record_filename_schemes %{
    "id" => Fact.Storage.Driver.ByEventId,
    "cas" => Fact.Storage.Driver.ContentAddressable
  }

  @record_file_format %{
    "json" => Fact.Storage.Format.Json
  }

  @indexer_modules %{
    "event_data" => Fact.EventDataIndexer,
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

    {:module, driver_module} =
      Code.ensure_loaded(@record_filename_schemes[manifest["records"]["filename_scheme"]])

    {:module, format_module} =
      Code.ensure_loaded(@record_file_format[manifest["records"]["file_format"]])

    config =
      %{
        manifest_version: Version.parse!(manifest["manifest_version"]),
        elixir_version: Version.parse!(manifest["elixir_version"]),
        engine_version: Version.parse!(manifest["engine_version"]),
        index_version: Version.parse!(manifest["index_version"]),
        os_version: manifest["os_version"],
        otp_version: manifest["otp_version"],
        record_version: Version.parse!(manifest["record_version"]),
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
          old_format: format_module,
          old_driver: driver_module
        },
        indexers:
          Enum.map(manifest["indexers"], fn indexer ->
            module = @indexer_modules[indexer["name"]]

            old_encoding =
              if indexer["filename_scheme"] === "raw",
                do: :raw,
                else: {:hash, String.to_atom(indexer["hash_algorithm"])}

            %{
              module: module,
              name: String.to_atom(indexer["name"]),
              filename_scheme: String.to_atom(indexer["filename_scheme"]),
              hash_algorithm:
                if(not is_nil(indexer["hash_algorithm"]),
                  do: String.to_atom(indexer["hash_algorithm"]),
                  else: nil
                ),
              hash_encoding:
                if(not is_nil(indexer["hash_encoding"]),
                  do: String.to_atom(indexer["hash_encoding"]),
                  else: nil
                ),
              old_spec:
                {@indexer_modules[indexer["name"]], [enabled: indexer["name"] != "event_data"]},
              old_path: Path.join([path, "indices", to_string(module)]),
              old_encoding: old_encoding
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
