defmodule Fact.Seam.EventSchema.Registry do
  use Fact.Seam.Registry,
    impls: [Fact.Seam.EventSchema.Standard.V1]
end
