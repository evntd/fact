defmodule Fact.Seam.Decoder.Integer.V1Test do
  use ExUnit.Case, async: true

  alias Fact.Seam.Decoder.Integer.V1

  test "decode/3 converts binary string to integer" do
    assert {:ok, 42} = V1.decode(%V1{}, "42", [])
  end

  test "decode/3 handles negative integers" do
    assert {:ok, -7} = V1.decode(%V1{}, "-7", [])
  end

  test "decode/3 returns error for non-integer string" do
    assert {:error, {:decode, "abc"}} = V1.decode(%V1{}, "abc", [])
  end

  test "decode/3 returns error for non-binary input" do
    assert {:error, {:decode, 123}} = V1.decode(%V1{}, 123, [])
  end
end
