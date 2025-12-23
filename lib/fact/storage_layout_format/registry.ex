defmodule Fact.StorageLayoutFormat.Registry do
  use Fact.Seam.Registry,
    impls: [Fact.StorageLayoutFormat.Default.V1]
end
