defmodule Fact.Seam.FileName.Registry do
  use Fact.Seam.Registry,
    impls: [
      Fact.Seam.FileName.EventId.V1,
      Fact.Seam.FileName.Fixed.V1,
      Fact.Seam.FileName.Hash.V1,
      Fact.Seam.FileName.Raw.V1
    ]
end
