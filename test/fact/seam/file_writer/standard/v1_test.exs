defmodule Fact.Seam.FileWriter.Standard.V1Test do
  use ExUnit.Case

  alias Fact.Seam.FileWriter.Standard.V1

  @moduletag :capture_log

  doctest V1

  test "module exists" do
    assert is_list(V1.module_info())
  end

  describe "id/0" do
    test "should be {:standard, 1}" do
      assert {:standard, 1} == V1.id()
    end
  end

  describe "family/0" do
    test "should be :standard" do
      assert :standard == V1.family()
    end
  end

  describe "version/0" do
    test "should be 1" do
      assert 1 == V1.version()
    end
  end

  describe "default_options/0" do
    test "should provide expected defaults" do
      assert %{access: :write, binary: true, exclusive: true, sync: false, worm: false} =
               V1.default_options()
    end
  end

  describe "init/1" do
    test "given empty map should return defaults as struct with computed modes" do
      %{access: a, binary: b, exclusive: e, sync: s, worm: w} = V1.default_options()

      assert %V1{sync: ^s, worm: ^w, modes: modes} = V1.init(%{})

      assert a in modes
      assert if(b, do: :binary) in modes
      assert if(e, do: :exclusive) in modes
    end

    test "can override access and keep others default" do
      %{sync: s, worm: w} = V1.default_options()

      assert %V1{modes: modes, sync: ^s, worm: ^w} =
               V1.init(%{access: :append})

      assert :append in modes
    end

    test "invalid option value should fail" do
      assert {:error, {:invalid_access_option, :nope}} ==
               V1.init(%{access: :nope})
    end

    test "unknown option should fail" do
      assert {:error, {:unknown_option, :bogus}} ==
               V1.init(%{bogus: true})
    end
  end

  describe "normalize_options/1" do
    test "valid values as strings convert to atoms" do
      assert {:ok, %{access: :append}} == V1.normalize_options(%{access: "append"})
      assert {:ok, %{binary: false}} == V1.normalize_options(%{binary: "false"})
    end

    test "invalid values should error" do
      assert {:error, {:invalid_binary_option, "sometimes"}} ==
               V1.normalize_options(%{binary: "sometimes"})

      assert {:error, {:invalid_exclusive_option, 1}} ==
               V1.normalize_options(%{exclusive: 1})
    end

    test "unknown keys should be removed" do
      assert {:ok, %{sync: true}} ==
               V1.normalize_options(%{sync: "true", extra: :ignored})
    end
  end
end
