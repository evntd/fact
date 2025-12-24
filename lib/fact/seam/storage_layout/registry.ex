defmodule Fact.Seam.StorageLayout.Registry do
  use Fact.Seam.Registry,
    impls: [Fact.Seam.StorageLayout.Standard.V1]
end
