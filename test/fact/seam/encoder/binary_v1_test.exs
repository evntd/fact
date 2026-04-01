defmodule Fact.Seam.Encoder.Binary.V1Test do
  use ExUnit.Case, async: true

  alias Fact.Seam.Encoder.Binary.V1

  test "encode/3 serializes a term to binary" do
    data = %{"key" => "value"}
    assert {:ok, binary} = V1.encode(%V1{}, data, [])
    assert is_binary(binary)
    assert :erlang.binary_to_term(binary) == data
  end
end
