defmodule Fact.Types do
  @type event_id :: String.t()
  @type event_data :: map()
  @type event_metadata :: map()
  @type event_position :: non_neg_integer()
  @type event_tag :: String.t()
  @type event_tags :: list(event_tag())
  @type event_type :: String.t()

  @typedoc """
  An event is a map with at least a `:type` key.
    
  It may also include:
    * `:id` - a UUID string
    * `:data` - a map of custom data
    * `:metadata` - a map of custom data about the data
    * `:tags` - a list of custom identifiers to aid in defining context boundaries
  """
  @type event :: %{
          required(:type) => event_type,
          optional(:id) => event_id,
          optional(:data) => event_data,
          optional(:metadata) => event_metadata,
          optional(:tags) => event_tags
        }

  @type record_id :: String.t()
end
