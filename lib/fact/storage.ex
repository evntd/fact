defmodule Fact.Storage do
  @moduledoc """
  Adapter for working with configurable storage implementations.
    
  There is currently only a single implementation, see `Fact.Seam.Storage.Standard.V1`.
  """
  use Fact.Seam.Storage.Adapter
end
