defmodule Fact.Seam.EventId.Registry do
  use Fact.Seam.Registry,
    impls: [
      Fact.Seam.EventId.Uuid.V4
    ]
end
