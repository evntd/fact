defmodule Fact.Seam.Instance do
  @moduledoc """
  Represents a specific configured instance of a `Fact.Seam` component.

  A `Fact.Seam.Instance` holds:

    * `:module` – the implementation module (usually a module that `use`s `Fact.Seam`)
    * `:state` – the initialized struct of the module, created via `init/1` with options

  This struct allows the Fact system to treat configured components uniformly,
  storing the module reference and its initialized state together for easy access.
  """

  @type t() :: %{
          required(:module) => atom(),
          required(:state) => struct()
        }

  @enforce_keys [:module, :state]
  defstruct [:module, :state]
end
