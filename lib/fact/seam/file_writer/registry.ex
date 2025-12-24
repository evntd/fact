defmodule Fact.Seam.FileWriter.Registry do
  use Fact.Seam.Registry,
    impls: [Fact.Seam.FileWriter.Standard.V1]
end
