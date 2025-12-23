defmodule Fact.StorageLayoutFormat.Registry do
  use Fact.Seam.Registry,
    default: {:default, 1},
    formats: [Fact.StorageLayoutFormat.Default.V1]
end
