defmodule Fact.Seam.Instance do
  @type t() :: %{
          required(:module) => atom(),
          required(:struct) => struct()
        }

  @enforce_keys [:module, :struct]
  defstruct [:module, :struct]
end
