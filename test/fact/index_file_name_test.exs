defmodule Fact.IndexFileNameTest do
  use ExUnit.Case

  alias Fact.IndexFileName

  @moduletag :capture_log

  doctest IndexFileName

  test "module exists" do
    assert is_list(IndexFileName.module_info())
  end
end
