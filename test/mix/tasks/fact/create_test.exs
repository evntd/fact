defmodule Mix.Tasks.Fact.CreateTest do
  use ExUnit.Case

  alias Fact.TestHelper
  alias Mix.Tasks.Fact.Create

  @moduletag :capture_log

  setup %{tmp_dir: path} do
    on_exit(fn -> TestHelper.rm_rf(path) end)
    :ok
  end

  @tag :tmp_dir
  test "should fail when path is not empty directory", %{tmp_dir: path} do
    Path.join(path, "file") |> File.touch!()

    assert_raise Mix.Error, ~r/^Requires the path to not exist or be empty:\.*/, fn ->
      Create.run(["-n", "test", "-p", path, "--quiet"])
    end
  end

  @tag :tmp_dir
  test "should fail when path is a file", %{tmp_dir: path} do
    file_path = Path.join(path, "file")
    File.touch!(file_path)

    assert_raise Mix.Error,
                 ~r/^Requires the path to be a directory, a file was specified:\.*/,
                 fn ->
                   Create.run(["-n", "test", "-p", file_path, "--quiet"])
                 end
  end

  @tag :tmp_dir
  test "should fail when a name is not specified", %{tmp_dir: path} do
    assert_raise Mix.Error, ~r/^Missing database name, use "mix fact.create --name <name>"/, fn ->
      Create.run(["-p", path, "--quiet"])
    end
  end

  @tag :tmp_dir
  test "should fail when name is too long", %{tmp_dir: path} do
    too_long = "this-is-a-really-really-long-name-that-should-be-an-invalid-database-name"

    assert_raise Mix.Error,
                 ~r/^Invalid database name, it may only be up to 63 characters in length./,
                 fn ->
                   Create.run(["-n", too_long, "-p", path, "--quiet"])
                 end
  end

  @tag :tmp_dir
  test "should fail when name contains invalid characters", %{tmp_dir: path} do
    invalid_chars = "this_contains-$invalid$-characters#"

    assert_raise Mix.Error,
                 ~r/^Invalid database name, it may only contain the characters a-z, 0-9, and - \(hyphen\).$/,
                 fn ->
                   Create.run(["-n", invalid_chars, "-p", path, "--quiet"])
                 end
  end

  @tag :tmp_dir
  test "should fail when --indexer-option has invalid format", %{tmp_dir: path} do
    name = "test" <> Fact.Uuid.v4()

    assert_raise Mix.Error,
                 ~r/^Invalid indexer option format, use <indexer>:<option>=<value>: invalid_indexer|filename_scheme|raw/,
                 fn ->
                   Create.run([
                     "-n",
                     name,
                     "-p",
                     path,
                     "--quiet",
                     "--indexer-option",
                     "invalid_indexer|filename_scheme|raw"
                   ])
                 end
  end

  @tag :tmp_dir
  test "should fail when --indexer-option defines invalid indexer", %{tmp_dir: path} do
    name = "test" <> Fact.Uuid.v4()

    assert_raise Mix.Error,
                 ~r/^Invalid indexer "invalid_indexer", use one of these:/,
                 fn ->
                   Create.run([
                     "-n",
                     name,
                     "-p",
                     path,
                     "--quiet",
                     "--indexer-option",
                     "invalid_indexer:filename_scheme=raw"
                   ])
                 end
  end

  @tag :tmp_dir
  test "should fail when --indexer-option defines invalid option", %{tmp_dir: path} do
    name = "test" <> Fact.Uuid.v4()

    assert_raise Mix.Error,
                 ~r/^Invalid event_type indexer option "invalid_option", use one of these:/,
                 fn ->
                   Create.run([
                     "-n",
                     name,
                     "-p",
                     path,
                     "--quiet",
                     "--indexer-option",
                     "event_type:invalid_option=raw"
                   ])
                 end
  end

  @tag :tmp_dir
  test "should fail when --indexer-option defines invalid filename_scheme value", %{tmp_dir: path} do
    name = "test" <> Fact.Uuid.v4()

    assert_raise Mix.Error,
                 ~r/^Invalid event_type filename_scheme value "invalid_value", use one of these:/,
                 fn ->
                   Create.run([
                     "-n",
                     name,
                     "-p",
                     path,
                     "--quiet",
                     "--indexer-option",
                     "event_type:filename_scheme=invalid_value"
                   ])
                 end
  end

  @tag :tmp_dir
  test "should fail when --indexer-option defines invalid hash_algorithm value", %{tmp_dir: path} do
    name = "test" <> Fact.Uuid.v4()

    assert_raise Mix.Error,
                 ~r/^Invalid event_type hash_algorithm value "invalid_value", use one of these:/,
                 fn ->
                   Create.run([
                     "-n",
                     name,
                     "-p",
                     path,
                     "--quiet",
                     "--indexer-option",
                     "event_type:hash_algorithm=invalid_value"
                   ])
                 end
  end

  @tag :tmp_dir
  test "should fail when --indexer-option defines invalid hash_encoding value", %{tmp_dir: path} do
    name = "test" <> Fact.Uuid.v4()

    assert_raise Mix.Error,
                 ~r/^Invalid event_type hash_encoding value "invalid_value", use one of these:/,
                 fn ->
                   Create.run([
                     "-n",
                     name,
                     "-p",
                     path,
                     "--quiet",
                     "--indexer-option",
                     "event_type:hash_encoding=invalid_value"
                   ])
                 end
  end

  @tag :tmp_dir
  test "should generate unique database ids", %{tmp_dir: path} do
    Create.run(["-n", "test", "-p", Path.join(path, "test1"), "-q"])
    Create.run(["-n", "test", "-p", Path.join(path, "test2"), "-q"])
    Create.run(["-n", "test", "-p", Path.join(path, "test3"), "-q"])

    manifest1 = read_manifest(Path.join(path, "test1"))
    manifest2 = read_manifest(Path.join(path, "test2"))
    manifest3 = read_manifest(Path.join(path, "test3"))

    assert manifest1["database_id"] != manifest2["database_id"]
    assert manifest1["database_id"] != manifest3["database_id"]
    assert manifest2["database_id"] != manifest3["database_id"]
  end

  describe "storage format" do
    @tag :tmp_dir
    test "should succeed by supplying name and path", %{tmp_dir: path} do
      Create.run(["-n", "test", "-p", path, "-q"])

      assert File.dir?(path)
      assert File.exists?(Path.join(path, "manifest"))
      assert File.exists?(Path.join(path, ".gitignore"))
      assert File.exists?(Path.join(path, ".ledger"))
      assert File.dir?(Path.join(path, "events"))
      assert File.dir?(Path.join(path, "indices"))
      assert File.dir?(Path.join(path, "indices/event_stream"))
      assert File.dir?(Path.join(path, "indices/event_type"))
      assert File.dir?(Path.join(path, "indices/event_tags"))
      assert File.dir?(Path.join(path, "indices/event_data"))
      refute File.dir?(Path.join(path, "indices/event_stream_category"))
      refute File.dir?(Path.join(path, "indices/event_streams"))
      refute File.dir?(Path.join(path, "indices/event_streams_by_category"))
    end

    @tag :tmp_dir
    test "--all-indexers should setup all indices", %{tmp_dir: path} do
      Create.run(["-n", "test", "-p", path, "-q", "--all-indexers"])

      assert File.dir?(path)
      assert File.exists?(Path.join(path, "manifest"))
      assert File.exists?(Path.join(path, ".gitignore"))
      assert File.exists?(Path.join(path, ".ledger"))
      assert File.dir?(Path.join(path, "events"))
      assert File.dir?(Path.join(path, "indices"))
      assert File.dir?(Path.join(path, "indices/event_stream"))
      assert File.dir?(Path.join(path, "indices/event_type"))
      assert File.dir?(Path.join(path, "indices/event_tags"))
      assert File.dir?(Path.join(path, "indices/event_data"))
      assert File.dir?(Path.join(path, "indices/event_stream_category"))
      assert File.dir?(Path.join(path, "indices/event_streams"))
      assert File.dir?(Path.join(path, "indices/event_streams_by_category"))
    end

    @tag :tmp_dir
    test "--indexers event_streams should configure indexer", %{tmp_dir: path} do
      Create.run(["-n", "test", "-p", path, "-q", "--indexer", "event_streams"])

      assert File.dir?(path)
      assert File.exists?(Path.join(path, "manifest"))
      assert File.exists?(Path.join(path, ".gitignore"))
      assert File.exists?(Path.join(path, ".ledger"))
      assert File.dir?(Path.join(path, "events"))
      assert File.dir?(Path.join(path, "indices"))
      assert File.dir?(Path.join(path, "indices/event_stream"))
      assert File.dir?(Path.join(path, "indices/event_type"))
      assert File.dir?(Path.join(path, "indices/event_tags"))
      assert File.dir?(Path.join(path, "indices/event_data"))
      refute File.dir?(Path.join(path, "indices/event_stream_category"))
      assert File.dir?(Path.join(path, "indices/event_streams"))
      refute File.dir?(Path.join(path, "indices/event_streams_by_category"))
    end
  end

  describe "manifest format" do
    @tag :tmp_dir
    test "default manifest file", %{tmp_dir: path} do
      Create.run(["-n", "test", "-p", path, "-q"])

      manifest = read_manifest(path)

      assert "test" === manifest["database_name"]
      assert manifest["database_id"]
      assert {:ok, _datetime, 0} = DateTime.from_iso8601(manifest["created_at"])

      assert "json" === manifest["records"]["file_format"]
      assert "id" === manifest["records"]["filename_scheme"]

      assert has_indexer_with_filename_scheme?(manifest["indexers"], "event_stream", "raw")
      assert has_indexer_with_filename_scheme?(manifest["indexers"], "event_tags", "raw")
      assert has_indexer_with_filename_scheme?(manifest["indexers"], "event_type", "raw")
      assert has_indexer_with_filename_scheme?(manifest["indexers"], "event_data", "raw")

      refute has_indexer?(manifest["indexers"], "event_stream_category")
      refute has_indexer?(manifest["indexers"], "event_streams")
      refute has_indexer?(manifest["indexers"], "event_streams_by_category")

      assert Version.match?(manifest["manifest_version"], ">= 0.1.0")
      assert Version.match?(manifest["engine_version"], ">= 0.0.1-alpha.1")
      assert Version.match?(manifest["record_version"], ">= 0.0.1")
      assert Version.match?(manifest["index_version"], ">= 0.0.1")
      assert Version.match?(manifest["storage_version"], ">= 0.0.1")
    end

    @tag :tmp_dir
    test "default index filename scheme", %{tmp_dir: path} do
      Create.run([
        "-n",
        "test",
        "-p",
        path,
        "-q",
        "--index-filename-scheme",
        "hash",
        "--index-hash-algorithm",
        "md5",
        "--index-hash-encoding",
        "url_encode64"
      ])

      manifest = read_manifest(path)

      assert has_indexer_with_filename_scheme?(manifest["indexers"], "event_stream", "hash")
      assert has_indexer_with_hash_algorithm?(manifest["indexers"], "event_stream", "md5")
      assert has_indexer_with_hash_encoding?(manifest["indexers"], "event_stream", "url_encode64")

      assert has_indexer_with_filename_scheme?(manifest["indexers"], "event_tags", "hash")
      assert has_indexer_with_hash_algorithm?(manifest["indexers"], "event_tags", "md5")
      assert has_indexer_with_hash_encoding?(manifest["indexers"], "event_tags", "url_encode64")

      assert has_indexer_with_filename_scheme?(manifest["indexers"], "event_type", "hash")
      assert has_indexer_with_hash_algorithm?(manifest["indexers"], "event_type", "md5")
      assert has_indexer_with_hash_encoding?(manifest["indexers"], "event_type", "url_encode64")

      assert has_indexer_with_filename_scheme?(manifest["indexers"], "event_data", "hash")
      assert has_indexer_with_hash_algorithm?(manifest["indexers"], "event_data", "md5")
      assert has_indexer_with_hash_encoding?(manifest["indexers"], "event_data", "url_encode64")

      refute has_indexer?(manifest["indexers"], "event_stream_category")
      refute has_indexer?(manifest["indexers"], "event_streams")
      refute has_indexer?(manifest["indexers"], "event_streams_by_category")
    end

    @tag :tmp_dir
    test "add indexer with custom indexer options", %{tmp_dir: path} do
      Create.run([
        "-n",
        "test",
        "-p",
        path,
        "-q",
        "--indexer",
        "event_streams",
        "--indexer-option",
        "event_streams:filename_scheme=hash",
        "--indexer-option",
        "event_streams:hash_algorithm=sha256",
        "--indexer-option",
        "event_streams:hash_encoding=encode32"
      ])

      manifest = read_manifest(path)

      assert has_indexer_with_filename_scheme?(manifest["indexers"], "event_streams", "hash")
      assert has_indexer_with_hash_algorithm?(manifest["indexers"], "event_streams", "sha256")
      assert has_indexer_with_hash_encoding?(manifest["indexers"], "event_streams", "encode32")
    end

    @tag :tmp_dir
    test "override indexer filename-scheme to raw", %{tmp_dir: path} do
      Create.run([
        "-n",
        "test",
        "-p",
        path,
        "-q",
        "--index-filename-scheme",
        "hash",
        "--index-hash-algorithm",
        "md5",
        "--index-hash-encoding",
        "url_encode64",
        "--indexer-option",
        "event_type:filename_scheme=raw"
      ])

      manifest = read_manifest(path)

      assert has_indexer_with_filename_scheme?(manifest["indexers"], "event_data", "hash")
      assert has_indexer_with_filename_scheme?(manifest["indexers"], "event_tags", "hash")
      assert has_indexer_with_filename_scheme?(manifest["indexers"], "event_stream", "hash")

      assert has_indexer_with_filename_scheme?(manifest["indexers"], "event_type", "raw")
      refute has_indexer_with_hash_algorithm?(manifest["indexers"], "event_type", "md5")
      refute has_indexer_with_hash_encoding?(manifest["indexers"], "event_type", "url_encode64")
    end
  end

  describe "IO" do
    @tag :tmp_dir
    test "displays banner, results, and next steps", %{tmp_dir: path} do
      Mix.shell(Mix.Shell.Process)

      Create.run(["-n", "test", "-p", path])

      manifest = read_manifest(path)

      assert_receive {:mix_shell, :info, [banner]}
      assert String.contains?(banner, "🐢")
      assert String.contains?(banner, "v#{Fact.MixProject.project()[:version]}")
      assert String.contains?(banner, "(#{Fact.MixProject.project()[:codename]})")

      assert_receive {:mix_shell, :info, [results]}
      assert String.contains?(results, "Database created, you're ready to rock!!! 🤘")
      assert String.contains?(results, "ID: #{manifest["database_id"]}")
      assert String.contains?(results, "NAME: #{manifest["database_name"]}")
      assert String.contains?(results, "PATH: #{Path.absname(path)}")

      assert_receive {:mix_shell, :info, [next_steps]}
      assert String.contains?(next_steps, "Next Steps:")
      assert String.contains?(next_steps, "Read the documentation")
      assert String.contains?(next_steps, "Relax, don't worry, have a homebrew")
    end
  end

  def read_manifest(path) do
    "manifest"
    |> then(&Path.join(path, &1))
    |> File.read!()
    |> Fact.Json.decode!()
  end

  def has_indexer?(indexers, indexer) do
    Enum.any?(indexers, fn i -> i["name"] === indexer end)
  end

  def has_indexer_with_filename_scheme?(indexers, indexer, filename_scheme) do
    Enum.any?(indexers, fn i ->
      i["name"] === indexer and i["filename_scheme"] === filename_scheme
    end)
  end

  def has_indexer_with_hash_algorithm?(indexers, indexer, hash_algorithm) do
    Enum.any?(indexers, fn i ->
      i["name"] === indexer and i["hash_algorithm"] === hash_algorithm
    end)
  end

  def has_indexer_with_hash_encoding?(indexers, indexer, hash_encoding) do
    Enum.any?(indexers, fn i ->
      i["name"] === indexer and i["hash_encoding"] === hash_encoding
    end)
  end
end
