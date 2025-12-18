defmodule Fact.ConcurrencyErrorTest do
  use ExUnit.Case

  describe "message" do
    test ":all with position" do
      assert_raise Fact.ConcurrencyError, "expected store_position to be 2, but was 3", fn ->
        raise Fact.ConcurrencyError.exception(source: :all, expected: 2, actual: 3)
      end
    end

    test "stream with :none" do
      assert_raise Fact.ConcurrencyError, "expected \"test\" stream to not exist", fn ->
        raise Fact.ConcurrencyError.exception(source: "test", expected: :none, actual: 3)
      end
    end

    test "stream with :exists" do
      assert_raise Fact.ConcurrencyError, "expected \"test\" stream to exist", fn ->
        raise Fact.ConcurrencyError.exception(source: "test", expected: :exists, actual: 0)
      end
    end

    test "stream with position" do
      assert_raise Fact.ConcurrencyError,
                   "expected \"test\" stream_position to be 1, but was 2",
                   fn ->
                     raise Fact.ConcurrencyError.exception(source: "test", expected: 1, actual: 2)
                   end
    end
  end
end
