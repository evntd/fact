defmodule Fact.QueryItemTest do
  use ExUnit.Case, async: true

  doctest Fact.QueryItem

  alias Fact.QueryItem

  describe "hash/1" do
    test "produces consistent hashes" do
      item = QueryItem.tags("tag1")
      assert QueryItem.hash(item) == QueryItem.hash(item)
    end

    test "different items produce different hashes" do
      a = QueryItem.tags("tag1")
      b = QueryItem.tags("tag2")
      assert QueryItem.hash(a) != QueryItem.hash(b)
    end

    test "hashes a list of query items" do
      items = [QueryItem.tags("tag1"), QueryItem.types("Type1")]
      hash = QueryItem.hash(items)
      assert is_binary(hash)
      assert String.length(hash) == 40
    end

    test "raises on invalid query item" do
      assert_raise ArgumentError, fn -> QueryItem.hash(:invalid) end
    end
  end

  describe "sources/1" do
    test "returns tag index sources" do
      item = QueryItem.tags(["tag1", "tag2"])
      sources = QueryItem.sources(item)

      assert {:index, {Fact.EventTagsIndexer, nil}, "tag1"} in sources
      assert {:index, {Fact.EventTagsIndexer, nil}, "tag2"} in sources
    end

    test "returns type index sources" do
      item = QueryItem.types(["Type1", "Type2"])
      sources = QueryItem.sources(item)

      assert {:index, {Fact.EventTypeIndexer, nil}, "Type1"} in sources
      assert {:index, {Fact.EventTypeIndexer, nil}, "Type2"} in sources
    end

    test "returns data index sources" do
      item = QueryItem.data(name: "Jake", hobby: "Coding")
      sources = QueryItem.sources(item)

      assert {:index, {Fact.EventDataIndexer, "name"}, "Jake"} in sources
      assert {:index, {Fact.EventDataIndexer, "hobby"}, "Coding"} in sources
    end

    test "returns sources for a list of query items" do
      items = [QueryItem.tags("t1"), QueryItem.types("T1")]
      sources = QueryItem.sources(items)

      assert {:index, {Fact.EventTagsIndexer, nil}, "t1"} in sources
      assert {:index, {Fact.EventTypeIndexer, nil}, "T1"} in sources
    end
  end

  describe "to_function/1" do
    test "returns a function for :all" do
      fun = QueryItem.to_function(:all)
      assert is_function(fun, 1)
    end

    test "returns a function for :none" do
      fun = QueryItem.to_function(:none)
      assert is_function(fun, 1)
    end

    test "returns a function for a struct" do
      fun = QueryItem.tags("tag1") |> QueryItem.to_function()
      assert is_function(fun, 1)
    end

    test "returns a function for a list of items" do
      items = [QueryItem.tags("t1"), QueryItem.types("T1")]
      fun = QueryItem.to_function(items)
      assert is_function(fun, 1)
    end
  end

  describe "join/1" do
    test "empty list returns :all" do
      assert QueryItem.join([]) == :all
    end

    test "all :none returns :none" do
      assert QueryItem.join([:none, :none]) == :none
    end
  end
end
