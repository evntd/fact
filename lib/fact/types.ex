defmodule Fact.Types do
  @typedoc """
  An event is a map with at least a `:type` key.
    
  It may also include:
    * `:id` - a UUID string
    * `:data` - a map of custom data
    * `:metadata` - a map of custom data about the data
    * `:tags` - a list of custom identifiers to aid in defining context boundaries
  """
  @type event :: %{
          required(:type) => String.t(),
          optional(:id) => String.t(),
          optional(:data) => map(),
          optional(:metadata) => map(),
          optional(:tags) => [String.t()]
        }
end
