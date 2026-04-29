defmodule Fact.Seam.FileName do
  @moduledoc """
  Behaviour defining the contract for generating file names within the Fact system.

  Implementations of this seam are responsible for producing a file name based 
  on a given value and optional parameters. This allows flexible naming strategies 
  that can be swapped or configured per database or file type.

  ## Callback

    * `get/3` – Generates a file name for the given value using the configured
      implementation and options. Returns `{:ok, path}` on success or
      `{:error, reason}` on failure.
  """

  use Fact.Seam

  @callback get(state :: t(), value :: term(), opts :: keyword()) ::
              {:ok, Path.t()} | {:error, term()}
end
