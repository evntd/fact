defmodule Fact.IndexFile.NameTest do
  use ExUnit.Case

  alias Fact.IndexFile.Name

  @moduletag :capture_log

  doctest Name

  test "module exists" do
    assert is_list(Name.module_info())
  end
end
