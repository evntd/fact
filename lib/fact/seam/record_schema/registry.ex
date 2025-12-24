defmodule Fact.Seam.RecordSchema.Registry do
  use Fact.Seam.Registry,
    impls: [Fact.Seam.RecordSchema.Standard.V1]
end
