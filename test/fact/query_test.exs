defmodule Fact.QueryTest do
  use ExUnit.Case, async: true

  alias Fact.Query

  describe "combine/2" do
    test ":and combines queries with logical AND" do
      q1 = fn _ctx -> fn id -> id == "a" end end
      q2 = fn _ctx -> fn id -> id in ["a", "b"] end end

      {:ok, combined} = Query.combine(:and, [q1, q2])
      pred = combined.("ctx")

      assert pred.("a") == true
      assert pred.("b") == false
    end

    test ":or combines queries with logical OR" do
      q1 = fn _ctx -> fn id -> id == "a" end end
      q2 = fn _ctx -> fn id -> id == "b" end end

      {:ok, combined} = Query.combine(:or, [q1, q2])
      pred = combined.("ctx")

      assert pred.("a") == true
      assert pred.("b") == true
      assert pred.("c") == false
    end

    test "single query returns it directly" do
      q = fn _ctx -> fn _id -> true end end

      assert {:ok, ^q} = Query.combine(:and, [q])
    end

    test "empty list returns error" do
      assert {:error, :empty_query_list} = Query.combine(:and, [])
    end

    test "invalid op returns error" do
      q = fn _ctx -> fn _id -> true end end

      assert {:error, :invalid_op} = Query.combine(:xor, [q, q])
    end

    test "non-function query returns error" do
      assert {:error, :non_function_query} = Query.combine(:and, ["not a function"])
    end
  end

  describe "combine!/2" do
    test "returns the combined query" do
      q = fn _ctx -> fn _id -> true end end

      result = Query.combine!(:and, [q, q])
      assert is_function(result)
    end

    test "raises on empty list" do
      assert_raise ArgumentError, ~r/at least one/, fn ->
        Query.combine!(:and, [])
      end
    end

    test "raises on invalid op" do
      q = fn _ctx -> fn _id -> true end end

      assert_raise ArgumentError, ~r/invalid operation/, fn ->
        Query.combine!(:bad, [q, q])
      end
    end

    test "raises on non-function" do
      assert_raise ArgumentError, fn ->
        Query.combine!(:and, [:not_a_function])
      end
    end
  end

  describe "from_all/0" do
    test "returns a function that always returns true" do
      fun = Query.from_all()
      pred = fun.("any_db")
      assert pred.("any_event") == true
    end
  end

  describe "from_none/0" do
    test "returns a function that always returns false" do
      fun = Query.from_none()
      pred = fun.("any_db")
      assert pred.("any_event") == false
    end
  end

  describe "from/3" do
    test "returns error when all criteria are empty" do
      assert {:error, :no_criteria} = Query.from([], [], [])
      assert {:error, :no_criteria} = Query.from(nil, nil, nil)
    end
  end

  describe "from_types/1" do
    test "returns error for empty list" do
      assert {:error, :empty_type_list} = Query.from_types([])
    end

    test "returns error for non-string types" do
      assert {:error, :invalid_type_criteria} = Query.from_types([:atom_type])
    end

    test "returns ok with valid types" do
      assert {:ok, fun} = Query.from_types(["TypeA", "TypeB"])
      assert is_function(fun)
    end

    test "accepts a single string" do
      assert {:ok, fun} = Query.from_types("TypeA")
      assert is_function(fun)
    end
  end

  describe "from_types!/1" do
    test "raises on error" do
      assert_raise ArgumentError, fn -> Query.from_types!([]) end
    end

    test "returns function on success" do
      assert is_function(Query.from_types!("TypeA"))
    end
  end

  describe "from_tags/1" do
    test "returns error for empty list" do
      assert {:error, :empty_tag_list} = Query.from_tags([])
    end

    test "returns error for non-string tags" do
      assert {:error, :invalid_tag_criteria} = Query.from_tags([:atom_tag])
    end

    test "returns ok with valid tags" do
      assert {:ok, fun} = Query.from_tags(["tag1", "tag2"])
      assert is_function(fun)
    end

    test "accepts a single string" do
      assert {:ok, fun} = Query.from_tags("tag1")
      assert is_function(fun)
    end
  end

  describe "from_tags!/1" do
    test "raises on error" do
      assert_raise ArgumentError, fn -> Query.from_tags!([]) end
    end
  end

  describe "from_data/1" do
    test "returns error for empty list" do
      assert {:error, :empty_data_list} = Query.from_data([])
    end

    test "returns ok with valid keyword data" do
      assert {:ok, fun} = Query.from_data(name: "Jake")
      assert is_function(fun)
    end
  end

  describe "from_data!/1" do
    test "raises on error" do
      assert_raise ArgumentError, fn -> Query.from_data!([]) end
    end
  end
end
