defmodule Fact.Seam.Decoder.Registry do
  use Fact.Seam.Registry,
    impls: [
      Fact.Seam.Decoder.Delimited.V1,
      Fact.Seam.Decoder.Integer.V1,
      Fact.Seam.Decoder.Json.V1,
      Fact.Seam.Decoder.Raw.V1
    ]
end
