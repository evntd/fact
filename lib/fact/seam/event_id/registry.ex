defmodule Fact.Seam.EventId.Registry do
  @moduledoc """
  Registry for `Fact.Seam.EventId` implementations.

  Currently includes:

    * `Fact.Seam.EventId.Uuid.V4`
  """
  use Fact.Seam.Registry,
    impls: [
      Fact.Seam.EventId.Uuid.V4
    ]
end
