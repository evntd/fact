defmodule Fact.Seam.ParsersTest do
  use ExUnit.Case

  alias Fact.Seam.Parsers

  @moduletag :capture_log

  doctest Parsers

  test "module exists" do
    assert is_list(Parsers.module_info())
  end

  describe "parse_field_name/1" do
    test "accepts valid field names starting with a letter" do
      assert {:ok, "name"} = Parsers.parse_field_name("name")
    end

    test "accepts valid field names starting with an underscore" do
      assert {:ok, "_name"} = Parsers.parse_field_name("_name")
      assert {:ok, "__Tags__"} = Parsers.parse_field_name("__Tags__")
      assert {:ok, "_"} = Parsers.parse_field_name("_")
    end

    test "accepts field names with numbers after the first character" do
      assert {:ok, "field1"} = Parsers.parse_field_name("field1")
      assert {:ok, "event_2"} = Parsers.parse_field_name("event_2")
      assert {:ok, "_123"} = Parsers.parse_field_name("_123")
    end

    test "accepts atoms and converts them to strings" do
      assert {:ok, "name"} = Parsers.parse_field_name(:name)
      assert {:ok, "_name"} = Parsers.parse_field_name(:_name)
      assert {:ok, "__field_1__"} = Parsers.parse_field_name(:__field_1__)
    end

    test "rejects field names starting with a number" do
      assert :error = Parsers.parse_field_name("1field")
      assert :error = Parsers.parse_field_name("123")
    end

    test "rejects field names that are empty" do
      assert :error = Parsers.parse_field_name("")
    end

    test "rejects field names with invalid characters" do
      assert :error = Parsers.parse_field_name("field-name")
      assert :error = Parsers.parse_field_name("field.name")
      assert :error = Parsers.parse_field_name("field name")
      assert :error = Parsers.parse_field_name("field:name")
      assert :error = Parsers.parse_field_name("field@name")
    end

    test "rejects non-string and non-atom values" do
      assert :error = Parsers.parse_field_name(123)
      assert :error = Parsers.parse_field_name(nil)
      assert :error = Parsers.parse_field_name([])
      assert :error = Parsers.parse_field_name(%{})
    end
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

  describe "parse_existing_atom/1" do
    test "accepts existing atom as binary" do
      assert {:ok, :sha256} = Parsers.parse_existing_atom("sha256")
    end

    test "accepts atom directly" do
      assert {:ok, :sha256} = Parsers.parse_existing_atom(:sha256)
    end

    test "rejects non-existing atom string" do
      assert :error = Parsers.parse_existing_atom("this_atom_definitely_does_not_exist_xyz_999")
    end

    test "rejects non-string non-atom" do
      assert :error = Parsers.parse_existing_atom(123)
    end
  end

  describe "parse_filename/1" do
    test "accepts simple filenames" do
      assert {:ok, "file.txt"} = Parsers.parse_filename("file.txt")
      assert {:ok, "my-file_v2.json"} = Parsers.parse_filename("my-file_v2.json")
    end

    test "rejects filenames with directory components" do
      assert :error = Parsers.parse_filename("path/to/file.txt")
    end

    test "rejects filenames with spaces" do
      assert :error = Parsers.parse_filename("my file.txt")
    end

    test "rejects non-binary" do
      assert :error = Parsers.parse_filename(123)
    end
  end

  describe "parse_directory/1" do
    test "accepts valid directory paths" do
      assert {:ok, "tmp/data"} = Parsers.parse_directory("tmp/data")
      assert {:ok, "/abs/path"} = Parsers.parse_directory("/abs/path")
      assert {:ok, "."} = Parsers.parse_directory(".")
      assert {:ok, ".."} = Parsers.parse_directory("..")
    end
  end

  describe "parse_pos_integer/1" do
    test "accepts positive integers" do
      assert {:ok, 1} = Parsers.parse_pos_integer(1)
      assert {:ok, 42} = Parsers.parse_pos_integer(42)
    end

    test "accepts positive integer strings" do
      assert {:ok, 5} = Parsers.parse_pos_integer("5")
    end

    test "rejects zero and negatives" do
      assert :error = Parsers.parse_pos_integer(0)
      assert :error = Parsers.parse_pos_integer(-1)
    end

    test "rejects non-numeric" do
      assert :error = Parsers.parse_pos_integer("abc")
      assert :error = Parsers.parse_pos_integer(nil)
    end
  end

  describe "parse_non_neg_integer/1" do
    test "accepts zero and positive integers" do
      assert {:ok, 0} = Parsers.parse_non_neg_integer(0)
      assert {:ok, 5} = Parsers.parse_non_neg_integer(5)
    end

    test "accepts non-negative integer strings" do
      assert {:ok, 0} = Parsers.parse_non_neg_integer("0")
    end

    test "rejects negatives" do
      assert :error = Parsers.parse_non_neg_integer(-1)
    end

    test "rejects non-numeric" do
      assert :error = Parsers.parse_non_neg_integer("abc")
      assert :error = Parsers.parse_non_neg_integer(nil)
    end
  end

  describe "parse_pos_integer/1 edge cases" do
    test "rejects float" do
      assert :error = Parsers.parse_pos_integer(1.5)
    end

    test "string negative" do
      assert :error = Parsers.parse_pos_integer("-1")
    end

    test "string zero" do
      assert :error = Parsers.parse_pos_integer("0")
    end
  end

  describe "parse_non_neg_integer/1 edge cases" do
    test "rejects float" do
      assert :error = Parsers.parse_non_neg_integer(1.5)
    end
  end
end
