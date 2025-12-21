defmodule Fact.EventTagsIndexerTest do
  use ExUnit.Case

  alias Fact.EventTagsIndexer

  @moduletag :capture_log

  doctest EventTagsIndexer
end
