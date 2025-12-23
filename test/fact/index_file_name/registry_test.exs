defmodule Fact.IndexFileName.RegistryTest do
  use ExUnit.Case

  alias Fact.IndexFileName.Registry

  @moduletag :capture_log

  doctest Registry

  test "module exists" do
    assert is_list(Registry.module_info())
  end

  test "default/0 should return {:raw, 1}" do
    assert {:raw, 1} == Registry.default()
  end

  describe "resolve/2" do
    test "given :raw, 1 should resolve" do
      assert Fact.IndexFileName.Raw.V1 == Registry.resolve(:raw, 1)
    end

    test "given :hash, 1 should resolve" do
      assert Fact.IndexFileName.Hash.V1 == Registry.resolve(:hash, 1)
    end

    test "given :other, 1 should fail" do
      assert {:error, {:unsupported_format, :other, 1}} == Registry.resolve(:other, 1)
    end
  end

  describe "latest/1" do
    test "given :raw" do
      assert Fact.IndexFileName.Raw.V1 == Registry.latest(:raw)
    end

    test "given :hash should be 1" do
      assert Fact.IndexFileName.Hash.V1 == Registry.latest(:hash)
    end

    test "given :other should fail" do
      assert {:error, :unsupported_format} == Registry.latest(:other)
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
      assert {:error, :unsupported_format} == Registry.latest_version(:other)
    end
  end
end
