defmodule Fact.Seam.ParsersTest do
  use ExUnit.Case

  alias Fact.Seam.Parsers

  @moduletag :capture_log

  doctest Parsers

  test "module exists" do
    assert is_list(Parsers.module_info())
  end

  describe "parse_integer_range/3" do
    test "accepts integers within the range" do
      assert {:ok, 5} = Parsers.parse_integer_range(5, 1, 10)
      assert {:ok, 1} = Parsers.parse_integer_range(1, 1, 10)
      assert {:ok, 10} = Parsers.parse_integer_range(10, 1, 10)
    end

    test "accepts negative integers within the range" do
      assert {:ok, -5} = Parsers.parse_integer_range(-5, -10, -1)
      assert {:ok, 0} = Parsers.parse_integer_range(0, -10, 10)
    end

    test "rejects integers below the minimum" do
      assert :error = Parsers.parse_integer_range(0, 1, 10)
      assert :error = Parsers.parse_integer_range(-1, 0, 10)
    end

    test "rejects integers above the maximum" do
      assert :error = Parsers.parse_integer_range(11, 1, 10)
      assert :error = Parsers.parse_integer_range(100, 1, 10)
    end

    test "accepts and parses valid string integers within the range" do
      assert {:ok, 5} = Parsers.parse_integer_range("5", 1, 10)
      assert {:ok, 1} = Parsers.parse_integer_range("1", 1, 10)
      assert {:ok, 10} = Parsers.parse_integer_range("10", 1, 10)
    end

    test "rejects string integers outside the range" do
      assert :error = Parsers.parse_integer_range("0", 1, 10)
      assert :error = Parsers.parse_integer_range("11", 1, 10)
    end

    test "rejects non-numeric strings" do
      assert :error = Parsers.parse_integer_range("abc", 1, 10)
      assert :error = Parsers.parse_integer_range("1.5", 1, 10)
      assert :error = Parsers.parse_integer_range("", 1, 10)
    end

    test "rejects non-integer and non-string values" do
      assert :error = Parsers.parse_integer_range(5.0, 1, 10)
      assert :error = Parsers.parse_integer_range(nil, 1, 10)
      assert :error = Parsers.parse_integer_range(:five, 1, 10)
      assert :error = Parsers.parse_integer_range([], 1, 10)
      assert :error = Parsers.parse_integer_range(%{}, 1, 10)
    end
  end
end
