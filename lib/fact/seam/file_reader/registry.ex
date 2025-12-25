defmodule Fact.Seam.FileReader.Registry do
  use Fact.Seam.Registry,
    impls: [Fact.Seam.FileReader.Standard.V1]
end
