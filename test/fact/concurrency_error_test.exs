defmodule Fact.ConcurrencyErrorTest do
  use ExUnit.Case, async: true

  alias Fact.ConcurrencyError

  describe "exception/1" do
    test "creates struct with source, expected, and actual" do
      error = ConcurrencyError.exception(source: :all, expected: 5, actual: 3)

      assert %ConcurrencyError{source: :all, expected: 5, actual: 3} = error
    end
  end

  describe "message/1" do
    test "for :all source" do
      error = ConcurrencyError.exception(source: :all, expected: 5, actual: 3)

      assert ConcurrencyError.message(error) == "expected to be 5, but was 3"
    end

    test "for stream with :none expectation" do
      error = ConcurrencyError.exception(source: "orders", expected: :none, actual: 2)

      assert ConcurrencyError.message(error) =~ ~s(expected "orders" stream to not exist)
    end

    test "for stream with :exists expectation and actual 0" do
      error = ConcurrencyError.exception(source: "orders", expected: :exists, actual: 0)

      assert ConcurrencyError.message(error) =~ ~s(expected "orders" stream to exist)
    end

    test "for stream with integer expectation" do
      error = ConcurrencyError.exception(source: "orders", expected: 3, actual: 5)

      assert ConcurrencyError.message(error) =~ ~s(expected "orders" to be 3, but was 5)
    end
  end
end
