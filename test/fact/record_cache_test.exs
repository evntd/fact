defmodule Fact.RecordCacheTest do
  use ExUnit.Case

  @moduletag :capture_log

  alias Fact.RecordCache

  setup_all do
    path = TestHelper.create_db("cache_test_")
    on_exit(fn -> TestHelper.rm_rf(path) end)
    {:ok, db} = Fact.open(path, cache: [max_size: 10_000])
    {:ok, db: db}
  end

  describe "get/2" do
    test "returns :miss for unknown record", %{db: db} do
      assert :miss = RecordCache.get(db, "nonexistent")
    end

    test "returns :miss when cache is not enabled" do
      assert :miss = RecordCache.get("no_such_database_999", "record_id")
    end
  end

  describe "put/3 and get/2" do
    test "round-trip caches a record", %{db: db} do
      event = %{"event_type" => "Test", "event_data" => %{"x" => 1}}
      RecordCache.put(db, "rec_1", event)
      Process.sleep(50)

      assert {:ok, {"rec_1", ^event}} = RecordCache.get(db, "rec_1")
    end

    test "does not insert duplicate entries", %{db: db} do
      event = %{"event_type" => "Test"}
      RecordCache.put(db, "rec_dup", event)
      RecordCache.put(db, "rec_dup", %{"event_type" => "Different"})
      Process.sleep(50)

      assert {:ok, {"rec_dup", ^event}} = RecordCache.get(db, "rec_dup")
    end
  end

  describe "size/1" do
    test "returns size info", %{db: db} do
      {:ok, info} = RecordCache.size(db)

      assert is_integer(info.current)
      assert info.max == 10_000
      assert is_float(info.percentage)
    end

    test "returns error when not enabled" do
      assert {:error, :not_enabled} = RecordCache.size("nonexistent_db_999")
    end
  end

  describe "count/1" do
    test "returns item count", %{db: db} do
      assert {:ok, count} = RecordCache.count(db)
      assert is_integer(count)
    end

    test "returns error when not enabled" do
      assert {:error, :not_enabled} = RecordCache.count("nonexistent_db_999")
    end
  end

  describe "clear/1" do
    test "empties the cache", %{db: db} do
      RecordCache.put(db, "clear_test", %{"data" => "v"})
      Process.sleep(50)

      :ok = RecordCache.clear(db)

      assert :miss = RecordCache.get(db, "clear_test")
      assert {:ok, 0} = RecordCache.count(db)
    end

    test "returns error when not enabled" do
      assert {:error, :not_enabled} = RecordCache.clear("nonexistent_db_999")
    end
  end

  describe "top/2" do
    test "returns most frequently accessed records", %{db: db} do
      RecordCache.clear(db)

      RecordCache.put(db, "top_a", %{"a" => 1})
      RecordCache.put(db, "top_b", %{"b" => 2})
      Process.sleep(50)

      # Bump top_a by accessing it multiple times
      for _ <- 1..3, do: RecordCache.get(db, "top_a")
      Process.sleep(50)

      {:ok, top} = RecordCache.top(db, 2)
      assert length(top) == 2
      [{top_id, _freq} | _] = top
      assert top_id == "top_a"
    end

    test "returns error when not enabled" do
      assert {:error, :not_enabled} = RecordCache.top("nonexistent_db_999", 5)
    end
  end

  describe "eviction" do
    test "evicts entries when cache is full" do
      path = TestHelper.create_db("cache_evict_")
      on_exit(fn -> TestHelper.rm_rf(path) end)
      {:ok, db} = Fact.open(path, cache: [max_size: 500])

      for i <- 1..20 do
        RecordCache.put(db, "evict_#{i}", %{"n" => i})
      end

      Process.sleep(100)

      {:ok, info} = RecordCache.size(db)
      assert info.current <= info.max
    end
  end

  describe "decay" do
    test "evicts low-frequency entries on decay" do
      path = TestHelper.create_db("cache_decay_")
      on_exit(fn -> TestHelper.rm_rf(path) end)
      {:ok, db} = Fact.open(path, cache: [max_size: 10_000, decay_interval: 60_000])

      RecordCache.put(db, "decay_1", %{"v" => 1})
      Process.sleep(50)

      # Trigger decay — frequency 1 → 0 → evicted
      [{pid, _}] = Fact.Registry.lookup(db, Fact.RecordCache)
      send(pid, :decay)
      Process.sleep(50)

      assert :miss = RecordCache.get(db, "decay_1")
    end
  end
end
