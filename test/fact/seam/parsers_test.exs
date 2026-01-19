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
end
