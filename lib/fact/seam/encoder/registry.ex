defmodule Fact.Seam.Encoder.Registry do
  use Fact.Seam.Registry,
    impls: [
      Fact.Seam.Encoder.Delimited.V1,
      Fact.Seam.Encoder.Integer.V1,
      Fact.Seam.Encoder.Json.V1,
      Fact.Seam.Encoder.Raw.V1
    ]
end
