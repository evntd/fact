defmodule Fact.FileNameFormat do
  @moduledoc false
  use Fact.Seam

  @callback for(t(), term()) :: Path.t() | {:error, term()}
end
