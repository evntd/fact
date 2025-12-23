defmodule Fact.RecordSchemaFormat.Registry do
  use Fact.Seam.Registry,
    formats: [Fact.RecordSchemaFormat.Default.V1]
end
