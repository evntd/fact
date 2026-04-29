defmodule Fact.Seam.CodecTest do
  use ExUnit.Case, async: true

  describe "Decoder.Raw.V1" do
    alias Fact.Seam.Decoder.Raw.V1

    test "decode/3 returns binary as-is" do
      assert {:ok, "hello"} = V1.decode(%V1{}, "hello", [])
    end

    test "decode/3 returns error for non-binary" do
      assert {:error, {:decode, 123}} = V1.decode(%V1{}, 123, [])
    end

    test "decode/3 returns error for nil" do
      assert {:error, {:decode, nil}} = V1.decode(%V1{}, nil, [])
    end
  end

  describe "Encoder.Json.V1" do
    alias Fact.Seam.Encoder.Json.V1

    test "encode/3 encodes a map to JSON" do
      {:ok, json} = V1.encode(%V1{}, %{"key" => "value"}, [])
      assert is_binary(json)
      assert json =~ "key"
      assert json =~ "value"
    end

    test "encode/3 encodes a list" do
      {:ok, json} = V1.encode(%V1{}, [1, 2, 3], [])
      assert json == "[1,2,3]"
    end

    test "encode/3 encodes nested maps" do
      {:ok, json} = V1.encode(%V1{}, %{"a" => %{"b" => 1}}, [])
      assert json =~ "\"a\""
      assert json =~ "\"b\""
    end

    test "encode/3 encodes empty map" do
      {:ok, json} = V1.encode(%V1{}, %{}, [])
      assert json == "{}"
    end
  end
end
