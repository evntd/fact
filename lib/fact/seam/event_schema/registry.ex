defmodule Fact.Seam.EventSchema.Registry do
  @moduledoc """
  Registry of available `Fact.Seam.EventSchema` implementations.

  Currently includes the standard version 1 implementation.
  """
  use Fact.Seam.Registry,
    impls: [
      Fact.Seam.EventSchema.Emmett.V1,
      Fact.Seam.EventSchema.Standard.V1
    ]
end
