defmodule Fact.Seam.Capability.FixedSize do
  @callback size(impl :: struct) :: non_neg_integer()  
end
