defmodule Fact.Seam.FileWriter.Registry do
  @moduledoc """
  Registry of all configured `Fact.Seam.FileWriter` implementations.

  Provides a lookup for allowed implementations, their versions, and the latest default implementation.
  """
  use Fact.Seam.Registry,
    impls: [Fact.Seam.FileWriter.Standard.V1]
end
