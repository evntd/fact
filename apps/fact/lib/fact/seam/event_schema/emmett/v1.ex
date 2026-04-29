defmodule Fact.Seam.EventSchema.Emmett.V1 do
  @moduledoc """
  An EventSchema similar to the schema used in the Emmett NodeJs library.
    
  See the [definition on GitHub](https://github.com/kurrent-io/KurrentDB-Client-Dotnet/blob/master/src/KurrentDB.Client/Core/EventRecord.cs)

  ### Differences
    
  Emmetts event records do not support a field for event tags. By default `__tags__`
  is used, but this may be configured when the database is created.
    
  ```sh
  $ mix fact.create --path tmp/emmett-ish \\
      --event-schema emmett@1 \\
      --event-schema-options event_tags=tags
  ```
    
  Additionally, Emmett supports a `kind` field, which Fact does not support at this time.

  ### Example
    
  When using `emmett@1`, persisted event records will take the following shape, with the caveat that
  `__tags__` may differ if configured to something else.

  ```js
  {
    "data": {name: "Turts"},
    "messageId": "3bb4808303c847fd9ceb0a1251ef95da",
    "metadata": {"correlationId": "240d3c0e-3251-4076-a769-97a6a705533e"},
    "__tags__": ["turtle:1"],
    "type": "egg_hatched",
    "globalPosition": "2",
    "created": 1765039106962264,
    "streamName": "turtle-1",
    "streamPosition": 1,
  }
  ```
    
  """
  @moduledoc since: "0.2.0"
  use Fact.Seam.EventSchema,
    family: :emmett,
    version: 1

  import Fact.Seam.Parsers, only: [parse_field_name: 1]

  @typedoc """
  Configuration options for the Emmett event schema.
  """
  @typedoc since: "0.2.0"
  @type t() :: %__MODULE__{
          event_tags: String.t()
        }

  @default_event_tags "__tags__"

  @enforce_keys [:event_tags]
  defstruct [:event_tags]

  @doc """
  Gets the default options.
  """
  @doc since: "0.2.0"
  @impl true
  @spec default_options() :: t()
  def default_options(), do: %{event_tags: @default_event_tags}

  @doc """
  Gets the specification for the configuration options. 
  """
  @doc since: "0.2.0"
  @impl true
  def option_specs() do
    %{
      event_tags: %{
        allowed: :any,
        parse: &parse_field_name/1,
        error: :invalid_event_tags
      }
    }
  end

  @doc """
  Gets a map of the keys used for Emmett-like event records.
  """
  @doc since: "0.2.0"
  @spec get(t(), keyword()) :: Fact.event_record_schema()
  @impl true
  def get(%__MODULE__{event_tags: event_tags}, opts) when is_list(opts) do
    %{
      event_data: "data",
      event_id: "messageId",
      event_metadata: "metadata",
      event_tags: event_tags,
      event_type: "type",
      event_store_position: "globalPosition",
      event_store_timestamp: "created",
      event_stream_id: "streamName",
      event_stream_position: "streamPosition"
    }
  end
end
