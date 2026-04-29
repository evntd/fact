defmodule Fact.WriteAheadLog.EntryTest do
  use ExUnit.Case, async: true

  alias Fact.WriteAheadLog.Entry

  describe "create/2" do
    test "returns a struct with correct fields and computed CRC" do
      entry = Entry.create(1, "hello")

      assert %Entry{lsn: 1, data: "hello", is_checkpoint: false} = entry
      assert is_integer(entry.crc)
    end

    test "different data produces different CRC" do
      entry_a = Entry.create(1, "aaa")
      entry_b = Entry.create(1, "bbb")

      assert entry_a.crc != entry_b.crc
    end

    test "different LSN produces different CRC" do
      entry_a = Entry.create(1, "same")
      entry_b = Entry.create(2, "same")

      assert entry_a.crc != entry_b.crc
    end
  end

  describe "create/3" do
    test "with is_checkpoint: true" do
      entry = Entry.create(5, "checkpoint_data", true)

      assert entry.is_checkpoint == true
      assert entry.lsn == 5
    end
  end

  describe "serialize/1 and deserialize/1" do
    test "round-trip preserves all fields" do
      original = Entry.create(42, "test data")
      bin = Entry.serialize(original)
      assert is_binary(bin)

      assert {:ok, deserialized} = Entry.deserialize(bin)
      assert deserialized.lsn == original.lsn
      assert deserialized.data == original.data
      assert deserialized.crc == original.crc
      assert deserialized.is_checkpoint == original.is_checkpoint
    end

    test "round-trip with checkpoint entry" do
      original = Entry.create(10, "cp", true)
      assert {:ok, deserialized} = original |> Entry.serialize() |> Entry.deserialize()
      assert deserialized.is_checkpoint == true
    end
  end

  describe "deserialize/1 error cases" do
    test "returns error when data is corrupted" do
      entry = Entry.create(1, "original data that is long enough")
      bin = Entry.serialize(entry)

      # Corrupt bytes in the middle of the binary where the data field lives
      mid = div(byte_size(bin), 2)
      <<head::binary-size(mid), _::binary-size(2), tail::binary>> = bin
      corrupted = <<head::binary, 0, 0, tail::binary>>

      assert {:error, _reason} = Entry.deserialize(corrupted)
    end

    test "returns unexpected_format for non-Entry term" do
      bin = :erlang.term_to_binary(%{not: "an entry"})
      assert {:error, {:unexpected_format, _}} = Entry.deserialize(bin)
    end
  end
end
