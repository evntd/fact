defmodule Fact.IndexFileName.Registry do
  use Fact.SeamRegistry,
    default: {:raw, 1},
    formats: [
      Fact.IndexFileName.Raw.V1,
      Fact.IndexFileName.Hash.V1
    ]
end
