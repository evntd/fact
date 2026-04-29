defmodule Fact.Seam.FileWriter do
  @moduledoc """
  Behaviour defining the contract for writing files within the Fact system.

  Implementations of this seam are responsible for writing arbitrary values
  to a specified path. The behaviour allows different file writing strategies
  or formats to be used interchangeably.

  ## Callback

    * `write/4` – Writes a given value to the provided path using the configured
      implementation and options. Returns `:ok` on success, or `{:error, reason}`
      on failure.
  """
  use Fact.Seam

  @callback write(
              impl :: t(),
              path :: Path.t(),
              value :: term(),
              options :: keyword()
            ) :: :ok | {:error, reason :: term()}
end
