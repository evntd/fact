defmodule Fact.Seam.Decoder do
  @moduledoc """
  Behaviour defining how to decode stored records back into Elixir terms.

  Implementations of this seam provide the logic for transforming a binary
  or iodata record retrieved from storage into a usable Elixir data structure.

  ## Callback

    * `decode/3` – Decodes the given binary `value` using the seam instance.
      Accepts optional parameters via `opts`. Returns `{:ok, decoded}` on success
      or `{:error, reason}` on failure.
  """
  use Fact.Seam

  @callback decode(impl :: t(), value :: binary(), opts :: keyword()) ::
              {:ok, decoded :: term()} | {:error, reason :: term()}
end
