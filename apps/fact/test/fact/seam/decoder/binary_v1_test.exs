defmodule Fact.Seam.Decoder.Binary.V1Test do
  use ExUnit.Case, async: true

  alias Fact.Seam.Decoder.Binary.V1

  test "decode/3 deserializes a binary term" do
    data = %{"key" => "value", "num" => 42}
    binary = :erlang.term_to_binary(data)

    assert {:ok, ^data} = V1.decode(%V1{}, binary, [])
  end

  test "decode/3 round-trips with lists" do
    list = [1, 2, 3]
    binary = :erlang.term_to_binary(list)

    assert {:ok, ^list} = V1.decode(%V1{}, binary, [])
  end
end
