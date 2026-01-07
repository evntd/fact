defmodule Fact.Seam.Encoder.Registry do
  @moduledoc """
  Registry of all available `Fact.Seam.Encoder` implementations.

  This module tracks the known encoder versions and allows resolution of
  specific encoder implementations by family and version.
  """
  use Fact.Seam.Registry,
    impls: [
      Fact.Seam.Encoder.Delimited.V1,
      Fact.Seam.Encoder.Integer.V1,
      Fact.Seam.Encoder.Json.V1,
      Fact.Seam.Encoder.Raw.V1
    ]
end
