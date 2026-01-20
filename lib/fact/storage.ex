defmodule Fact.Storage do
  @moduledoc """
  Adapter for working with configurable storage implementations.
    
  There is currently only a single implementation, see `Fact.Seam.Storage.Standard.V1`.
  """
  use Fact.Seam.Storage.Adapter,
    allowed_impls: [
      {:standard, 1},
      {:standard, 2}
    ],
    default_impl: {:standard, 2}
end
