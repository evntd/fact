defmodule Fact.Seam.EventSchema.Kurrent.V1 do
  @moduledoc """
  An EventSchema similar to the schema used in the KurrentDB .NET client.
    
  See the [definition on GitHub](https://github.com/kurrent-io/KurrentDB-Client-Dotnet/blob/master/src/KurrentDB.Client/Core/EventRecord.cs)

  ### Differences
    
  Kurrent event records do not support a field for event tags. By default `__Tags__`
  is used, but this may be configured when the database is created.
    
  ```sh
  $ mix fact.create --path tmp/kurrent-ish \\
      --event-schema kurrent@1 \\
      --event-schema-options event_tags=Tags
  ```
    
  Additionally, Kurrent supports a `ContentType` field, which Fact does not support at this time.

  ### Example
    
  When using `kurrent@1`, persisted event records will take the following shape, with the caveat that
  `__Tags__` may differ if configured to something else.

  ```js
  {
    "Data": {name: "Turts"},
    "EventId": "3bb4808303c847fd9ceb0a1251ef95da",
    "EventMetadata": {"correlationId": "240d3c0e-3251-4076-a769-97a6a705533e"},
    "__Tags__": ["turtle:1"],
    "EventType": "egg_hatched",
    "Position": "2",
    "Created": 1765039106962264,
    "EventStreamId": "turtle-1",
    "EventNumber": 1,
  }
  ```
    
  """
  @moduledoc since: "0.2.0"
  use Fact.Seam.EventSchema,
    family: :kurrent,
    version: 1

  import Fact.Seam.Parsers, only: [parse_field_name: 1]

  @typedoc """
  Configuration options for the Kurrent v1 event schema.
  """
  @typedoc since: "0.2.0"
  @type t() :: %__MODULE__{
          event_tags: String.t()
        }

  @default_event_tags "__Tags__"

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
  Gets a map of the keys used for Kurrent-like event records.
  """
  @doc since: "0.2.0"
  @spec get(t(), keyword()) :: Fact.event_record_schema()
  @impl true
  def get(%__MODULE__{event_tags: event_tags}, opts) when is_list(opts) do
    %{
      event_data: "Data",
      event_id: "EventId",
      event_metadata: "Metadata",
      event_tags: event_tags,
      event_type: "EventType",
      event_store_position: "Position",
      event_store_timestamp: "Created",
      event_stream_id: "EventStreamId",
      event_stream_position: "EventNumber"
    }
  end
end
