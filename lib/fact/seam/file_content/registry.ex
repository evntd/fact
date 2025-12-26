defmodule Fact.Seam.FileContent.Registry do
  use Fact.Seam.Registry,
    impls: [
      Fact.Seam.FileContent.Delimited.V1,
      Fact.Seam.FileContent.Integer.V1,
      Fact.Seam.FileContent.Json.V1
    ]
end
