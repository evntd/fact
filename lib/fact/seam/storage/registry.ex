defmodule Fact.Seam.Storage.Registry do
  use Fact.Seam.Registry,
    impls: [Fact.Seam.Storage.Standard.V1]
end
