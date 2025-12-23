defmodule Fact.FileNameFormat.Registry do
  use Fact.Seam.Registry,
    impls: [
      Fact.FileNameFormat.ContentAddressable.V1,
      Fact.FileNameFormat.EventId.V1,
      Fact.FileNameFormat.Hash.V1,
      Fact.FileNameFormat.Raw.V1
    ]
end
