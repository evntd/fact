defmodule FactTest do
  use ExUnit.Case
  doctest Fact

  test "greets the world" do
    assert Fact.hello() == :world
  end
end
