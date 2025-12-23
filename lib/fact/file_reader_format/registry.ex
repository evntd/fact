defmodule Fact.FileReaderFormat.Registry do
  use Fact.Seam.Registry,
    impls: [Fact.FileReaderFormat.Standard.V1]  
end
