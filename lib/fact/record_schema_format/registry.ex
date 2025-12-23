defmodule Fact.RecordSchemaFormat.Registry do
  use Fact.Seam.Registry,
    impls: [Fact.RecordSchemaFormat.Default.V1]
end
