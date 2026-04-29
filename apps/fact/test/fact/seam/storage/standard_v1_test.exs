defmodule Fact.Seam.Storage.Standard.V1Test do
  use ExUnit.Case, async: true

  alias Fact.Seam.Storage.Standard.V1

  setup do
    {:ok, state: %V1{path: "/data/mydb"}}
  end

  test "path/2 returns the root path", %{state: s} do
    assert V1.path(s, []) == "/data/mydb"
  end

  test "records_path/3 returns events directory", %{state: s} do
    assert V1.records_path(s, nil, []) == "/data/mydb/events"
  end

  test "records_path/3 with record_id", %{state: s} do
    assert V1.records_path(s, "abc123", []) == "/data/mydb/events/abc123"
  end

  test "indices_path/2", %{state: s} do
    assert V1.indices_path(s, []) == "/data/mydb/indices"
  end

  test "ledger_path/2", %{state: s} do
    assert V1.ledger_path(s, []) == "/data/mydb"
  end

  test "locks_path/2", %{state: s} do
    assert V1.locks_path(s, []) == "/data/mydb"
  end

  test "merkle_mountain_range_path/2", %{state: s} do
    assert V1.merkle_mountain_range_path(s, []) == "/data/mydb/merkle"
  end

  test "write_ahead_log_path/2", %{state: s} do
    assert V1.write_ahead_log_path(s, []) == "/data/mydb/wal"
  end

  test "initialize_storage/2 creates directories" do
    path = Path.join(System.tmp_dir!(), "fact_v1_test_#{System.unique_integer([:positive])}")
    state = %V1{path: path}

    assert {:ok, ^path} = V1.initialize_storage(state, [])
    assert File.dir?(path)
    assert File.dir?(Path.join(path, "events"))
    assert File.dir?(Path.join(path, "indices"))
    assert File.exists?(Path.join(path, ".gitignore"))

    File.rm_rf!(path)
  end

  test "default_options/0" do
    assert %{path: nil} = V1.default_options()
  end
end
