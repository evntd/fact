defmodule Fact.StorageLayout.Registry do
  use Fact.SeamRegistry,
    default: {:default, 1},
    formats: [Fact.StorageLayout.Default.V1]
end
