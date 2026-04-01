defmodule Fact.Seam.Decoder.Delimited.V1Test do
  use ExUnit.Case, async: true

  alias Fact.Seam.Decoder.Delimited.V1

  test "decode/3 splits on newline delimiter" do
    state = %V1{delimiter: "\n"}
    assert {:ok, ["a", "b", "c"]} = V1.decode(state, "a\nb\nc", [])
  end

  test "decode/3 splits on CRLF delimiter" do
    state = %V1{delimiter: "\r\n"}
    assert {:ok, ["x", "y"]} = V1.decode(state, "x\r\ny", [])
  end

  test "decode/3 splits on RS delimiter" do
    state = %V1{delimiter: <<30>>}
    assert {:ok, ["1", "2"]} = V1.decode(state, "1" <> <<30>> <> "2", [])
  end

  test "decode/3 returns error for non-binary" do
    state = %V1{delimiter: "\n"}
    assert {:error, {:decode, 123}} = V1.decode(state, 123, [])
  end

  test "default_options/0" do
    assert %{delimiter: :lf} = V1.default_options()
  end

  test "prepare_options/1 converts atoms to delimiter strings" do
    assert %{delimiter: "\n"} = V1.prepare_options(%{delimiter: :lf})
    assert %{delimiter: "\r\n"} = V1.prepare_options(%{delimiter: :crlf})
    assert %{delimiter: <<30>>} = V1.prepare_options(%{delimiter: :rs})
  end
end
