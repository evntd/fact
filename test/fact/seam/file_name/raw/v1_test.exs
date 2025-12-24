defmodule Fact.Seam.FileName.Raw.V1Test do
  use ExUnit.Case

  alias Fact.Seam.FileName.Raw.V1

  @moduletag :capture_log

  doctest V1

  test "module exists" do
    assert is_list(V1.module_info())
  end
  
  describe "id/0" do
    test "should be {:raw, 1}" do
      assert {:raw, 1} === V1.id()
    end
  end

  describe "family/0" do
    test "should be :raw" do
      assert :raw === V1.family()
    end
  end

  describe "version/0" do
    test "should be 1" do
      assert 1 === V1.version()
    end
  end

  describe "metadata/0" do
    test "should be empty" do
      assert %{} === V1.default_options()
    end
  end

  describe "init/1" do
    test "given empty map should return default" do
      %{} = V1.default_options()
      assert %V1{} == V1.init(%{})
    end

    test "given invalid metadata, should fail" do
      assert {:error, {:unknown_option, %{invalid: "test"}}} == V1.init(%{invalid: "test"})
    end
  end

  describe "normalize_options/0" do
    test "given empty map should return empty map" do
      assert %{} == V1.normalize_options(%{})
    end

    test "given invalid options, should fail" do
      assert {:error, {:unknown_option, %{invalid: "test"}}} ==
               V1.normalize_options(%{invalid: "test"})
    end
  end

  describe "for/2" do
    test "should return the supplied index_value" do
      assert "test" == V1.for(V1.init(%{}), "test")
    end
  end
end
