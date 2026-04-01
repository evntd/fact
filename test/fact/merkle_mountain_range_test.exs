defmodule Fact.MerkleMountainRange.PureTest do
  use ExUnit.Case, async: true

  alias Fact.MerkleMountainRange

  describe "leaf_to_mmr_position/1" do
    test "known values" do
      assert MerkleMountainRange.leaf_to_mmr_position(0) == 0
      assert MerkleMountainRange.leaf_to_mmr_position(1) == 1
      assert MerkleMountainRange.leaf_to_mmr_position(2) == 3
      assert MerkleMountainRange.leaf_to_mmr_position(3) == 4
      assert MerkleMountainRange.leaf_to_mmr_position(4) == 7
      assert MerkleMountainRange.leaf_to_mmr_position(5) == 8
      assert MerkleMountainRange.leaf_to_mmr_position(6) == 10
      assert MerkleMountainRange.leaf_to_mmr_position(7) == 11
    end
  end

  describe "mmr_size_for_leaf_count/1" do
    test "known values" do
      assert MerkleMountainRange.mmr_size_for_leaf_count(0) == 0
      assert MerkleMountainRange.mmr_size_for_leaf_count(1) == 1
      assert MerkleMountainRange.mmr_size_for_leaf_count(2) == 3
      assert MerkleMountainRange.mmr_size_for_leaf_count(3) == 4
      assert MerkleMountainRange.mmr_size_for_leaf_count(4) == 7
      assert MerkleMountainRange.mmr_size_for_leaf_count(5) == 8
      assert MerkleMountainRange.mmr_size_for_leaf_count(6) == 10
      assert MerkleMountainRange.mmr_size_for_leaf_count(7) == 11
      assert MerkleMountainRange.mmr_size_for_leaf_count(8) == 15
    end
  end

  describe "peak_positions/1" do
    test "known values" do
      assert MerkleMountainRange.peak_positions(1) == [0]
      assert MerkleMountainRange.peak_positions(2) == [2]
      assert MerkleMountainRange.peak_positions(3) == [2, 3]
      assert MerkleMountainRange.peak_positions(4) == [6]
      assert MerkleMountainRange.peak_positions(5) == [6, 7]
      assert MerkleMountainRange.peak_positions(8) == [14]
    end

    test "empty" do
      assert MerkleMountainRange.peak_positions(0) == []
    end
  end

  describe "verify_proof/2" do
    test "valid proof constructed from known hashes" do
      leaf_0 = :crypto.hash(:sha256, "leaf0")
      leaf_1 = :crypto.hash(:sha256, "leaf1")
      parent = :crypto.hash(:sha256, leaf_0 <> leaf_1)

      proof = %{
        leaf_index: 0,
        leaf_hash: leaf_0,
        sibling_hashes: [leaf_1],
        peaks: [parent]
      }

      assert :ok = MerkleMountainRange.verify_proof(proof, :sha256)
    end

    test "invalid proof fails verification" do
      proof = %{
        leaf_index: 0,
        leaf_hash: :crypto.hash(:sha256, "wrong"),
        sibling_hashes: [:crypto.hash(:sha256, "sibling")],
        peaks: [:crypto.hash(:sha256, "peak")]
      }

      assert {:error, :proof_invalid} = MerkleMountainRange.verify_proof(proof, :sha256)
    end
  end
end

# defmodule Fact.MerkleMountainRange.IntegrationTest do
#   use ExUnit.Case

#   @moduletag :capture_log
#   @moduletag :mmr_integration

#   alias Fact.MerkleMountainRange

#   setup_all do
#     path = TestHelper.create_cas_db("mmr_int_")
#     on_exit(fn -> TestHelper.rm_rf(path) end)
#     {:ok, db} = Fact.open(path, merkle: [batch_size: 1, flush_interval: 100])

#     events = for i <- 1..4, do: %{type: "MmrTest", data: %{"n" => i}}
#     {:ok, _} = Fact.append_stream(db, events, "mmr-stream")

#     # Give the MMR time to start, catch up, and process live events
#     Process.sleep(3_000)
#     wait_for_leaf_count(db, 5, 30_000)

#     {:ok, db: db}
#   end

#   defp wait_for_leaf_count(db, expected, timeout) when timeout > 0 do
#     case MerkleMountainRange.leaf_count(db) do
#       {:ok, ^expected} -> :ok
#       {:ok, _} ->
#         Process.sleep(100)
#         wait_for_leaf_count(db, expected, timeout - 100)
#     end
#   end

#   defp wait_for_leaf_count(_, expected, _),
#     do: raise("MMR did not reach #{expected} leaves within timeout")

#   test "peaks/1 returns non-empty list of hashes", %{db: db} do
#     assert {:ok, peaks} = MerkleMountainRange.peaks(db)
#     assert is_list(peaks) and length(peaks) > 0
#     assert Enum.all?(peaks, &is_binary/1)
#   end

#   test "leaf_count/1 matches event count", %{db: db} do
#     assert {:ok, 5} = MerkleMountainRange.leaf_count(db)
#   end

#   test "create_proof/2 returns valid proof struct", %{db: db} do
#     assert {:ok, proof} = MerkleMountainRange.create_proof(db, 1)
#     assert is_integer(proof.leaf_index)
#     assert is_binary(proof.leaf_hash)
#     assert is_list(proof.sibling_hashes)
#     assert is_list(proof.peaks)
#   end

#   test "verify_proof/2 validates proof from create_proof", %{db: db} do
#     {:ok, proof} = MerkleMountainRange.create_proof(db, 2)
#     assert :ok = MerkleMountainRange.verify_proof(proof, :sha256)
#   end

#   test "verify/1 returns :ok for untampered database", %{db: db} do
#     assert :ok = MerkleMountainRange.verify(db)
#   end

#   test "create_proof/2 errors for out-of-range position", %{db: db} do
#     assert {:error, :position_out_of_range} = MerkleMountainRange.create_proof(db, 999)
#   end
# end

defmodule Fact.MerkleMountainRange.DisabledTest do
  use ExUnit.Case

  @moduletag :capture_log

  setup_all do
    path = TestHelper.create_db("mmr_off_")
    on_exit(fn -> TestHelper.rm_rf(path) end)
    {:ok, db} = Fact.open(path)
    {:ok, db: db}
  end

  test "peaks/1 returns error when not enabled", %{db: db} do
    assert {:error, :not_enabled} = Fact.MerkleMountainRange.peaks(db)
  end

  test "leaf_count/1 returns error when not enabled", %{db: db} do
    assert {:error, :not_enabled} = Fact.MerkleMountainRange.leaf_count(db)
  end
end
