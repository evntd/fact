defmodule Fact.Seam.EventSchema do
  @moduledoc """
  Behaviour defining how to retrieve the event schema for a Fact database.

  Implementations of this seam provide the mapping between logical event attributes
  and the string keys under which they are stored in the underlying event map.

  The schema returned must conform to `t:Fact.event_record_schema/0`, which defines
  the required keys for an event:

    * `:event_data`
    * `:event_id`
    * `:event_metadata`
    * `:event_tags`
    * `:event_type`
    * `:event_store_position`
    * `:event_store_timestamp`
    * `:event_stream_id`
    * `:event_stream_position`

  ## Callback

    * `get/2` – Returns the event schema for a given seam instance and optional parameters.
  """
  use Fact.Seam

  @callback get(t(), opts :: keyword()) :: Fact.event_record_schema()
end
