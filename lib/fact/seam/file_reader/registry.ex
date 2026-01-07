defmodule Fact.Seam.FileReader.Registry do
  @moduledoc """
  Registry for all `Fact.Seam.FileReader` implementations.

  Tracks available reader implementations and their versions, allowing the system to resolve and select a specific reader module when requested.
  """
  use Fact.Seam.Registry,
    impls: [
      Fact.Seam.FileReader.Full.V1,
      Fact.Seam.FileReader.FixedLength.V1
    ]
end
