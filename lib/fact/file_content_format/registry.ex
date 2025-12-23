defmodule Fact.FileContentFormat.Registry do
  use Fact.Seam.Registry,
    formats: [
      Fact.FileContentFormat.Delimited.V1,
      Fact.FileContentFormat.Json.V1
    ]  
end
