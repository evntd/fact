defmodule Fact.Seam.FileReader do
  @moduledoc """
  Behaviour defining the contract for reading files within the Fact system.

  Implementations of this seam are responsible for reading file contents from
  a specified path. Different reading strategies or formats can be implemented
  and swapped transparently (watch out for implicit coupling, it can bite).

  ## Callback

    * `read/3` – Reads data from the given path using the configured implementation
      and options. Returns `{:ok, enumerable}` on success or `{:error, reason}` on failure.
  """

  use Fact.Seam

  @callback read(impl :: t(), path :: Path.t(), opts :: keyword()) ::
              {:ok, Enumerable.t()} | {:error, term()}
end
