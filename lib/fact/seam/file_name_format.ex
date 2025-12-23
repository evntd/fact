defmodule Fact.Seam.FileNameFormat do
  use Fact.Seam

  @callback for(t(), term()) :: Path.t() | {:error, term()}
end
