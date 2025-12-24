defmodule Fact.FileReader.Registry do
  use Fact.Seam.Registry,
    impls: [Fact.FileReader.Standard.V1]
end
