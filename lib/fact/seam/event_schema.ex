defmodule Fact.Seam.EventSchema do
  use Fact.Seam

  @callback get(t(), opts :: keyword()) :: map()
end
