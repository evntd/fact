defmodule Fact.Seam.EventId do
  @moduledoc """
  Behaviour defining how to generate event ids for events in a Fact database.

  Implementations of this seam provide the logic for producing unique identifiers
  for events. The generated ID can be any binary value, such as a UUID or hash.

  ## Callback

    * `generate/2` – Generates a new event ID for the given seam instance. Accepts
      optional parameters via `opts`. Returns a binary ID or an error tuple.
  """
  use Fact.Seam

  @callback generate(state :: t(), opts :: keyword()) :: binary() | {:error, term()}
end
