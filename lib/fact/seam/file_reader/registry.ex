defmodule Fact.Seam.FileReader.Registry do
  use Fact.Seam.Registry,
    impls: [
      Fact.Seam.FileReader.Full.V1,
      Fact.Seam.FileReader.FixedLength.V1
    ]
end
