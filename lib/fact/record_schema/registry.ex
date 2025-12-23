defmodule Fact.RecordSchema.Registry do
  use Fact.SeamRegistry,
    default: {:default, 1},
    formats: [Fact.RecordSchema.Default.V1]
end
