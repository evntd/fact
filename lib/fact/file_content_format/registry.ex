defmodule Fact.FileContentFormat.Registry do
  use Fact.Seam.Registry,
    impls: [
      Fact.FileContentFormat.Delimited.V1,
      Fact.FileContentFormat.Json.V1
    ]
end
