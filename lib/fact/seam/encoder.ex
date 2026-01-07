defmodule Fact.Seam.Encoder do
  @moduledoc """
  Behaviour defining how to encode records before they are written to storage.

  Implementations of this seam provide the logic for transforming a record into
  a binary or iodata format suitable for persistence.

  ## Callback

    * `encode/3` – Encodes the given record using the seam instance. Accepts
      optional parameters via `opts`. Returns `{:ok, iodata()}` on success or
      `{:error, reason}` on failure.
  """

  use Fact.Seam

  @callback encode(t(), term(), keyword()) :: {:ok, iodata()} | {:error, term()}
end
