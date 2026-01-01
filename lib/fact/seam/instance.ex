defmodule Fact.Seam.Instance do
  @type t() :: %{
          required(:module) => atom(),
          required(:state) => struct()
        }

  @enforce_keys [:module, :state]
  defstruct [:module, :state]
end
