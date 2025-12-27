defmodule Fact.Seam.Behaviour.FixedSize do
  @callback size(impl :: struct) :: non_neg_integer()  
end
