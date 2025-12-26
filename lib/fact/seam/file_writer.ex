defmodule Fact.Seam.FileWriter do
  use Fact.Seam

  @callback write(
              impl :: t(),
              path :: Path.t(),
              value :: term(),
              options :: keyword()
            ) :: :ok | {:error, reason :: term()}
end
