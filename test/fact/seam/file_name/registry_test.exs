defmodule Fact.Seam.FileName.RegistryTest do
  use ExUnit.Case

  alias Fact.Seam.FileName.Registry

  @moduletag :capture_log

  doctest Registry

  test "module exists" do
    assert is_list(Registry.module_info())
  end

  describe "resolve/2" do
    test "given :raw, 1 should resolve" do
      assert Fact.Seam.FileName.Raw.V1 == Registry.resolve(:raw, 1)
    end

    test "given :hash, 1 should resolve" do
      assert Fact.Seam.FileName.Hash.V1 == Registry.resolve(:hash, 1)
    end

    test "given :event_id, 1 should resolve" do
      assert Fact.Seam.FileName.EventId.V1 == Registry.resolve(:event_id, 1)
    end

    test "given :content_addressable, 1 should resolve" do
      assert Fact.Seam.FileName.ContentAddressable.V1 ==
               Registry.resolve(:content_addressable, 1)
    end

    test "given :other, 1 should fail" do
      assert {:error, {:unsupported_impl, :other, 1}} == Registry.resolve(:other, 1)
    end
  end

  describe "latest_impl/1" do
    test "given :raw" do
      assert Fact.Seam.FileName.Raw.V1 == Registry.latest_impl(:raw)
    end

    test "given :hash should be 1" do
      assert Fact.Seam.FileName.Hash.V1 == Registry.latest_impl(:hash)
    end

    test "given :other should fail" do
      assert {:error, :unsupported_impl} == Registry.latest_impl(:other)
    end
  end

  describe "latest_version/1" do
    test "given :raw" do
      assert 1 == Registry.latest_version(:raw)
    end

    test "given :hash" do
      assert 1 == Registry.latest_version(:hash)
    end

    test "given :other should fail" do
      assert {:error, :unsupported_impl} == Registry.latest_version(:other)
    end
  end
end
