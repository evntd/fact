defmodule Fact.Seam.FileName.Registry do
  @moduledoc """
  Registry for all `Fact.Seam.FileName` implementations.

  Keeps track of available versions for generating file names, including event ID-based,
  fixed, hash-based, and raw strategies.
  """
  use Fact.Seam.Registry,
    impls: [
      Fact.Seam.FileName.EventId.V1,
      Fact.Seam.FileName.Fixed.V1,
      Fact.Seam.FileName.Hash.V1,
      Fact.Seam.FileName.Raw.V1
    ]
end
