defmodule Fact.Seam.EventSchema.Marten.V1 do
  @moduledoc """
  An EventSchema similar to the schema used in the MartenDB .NET client.
    
  See the [Marten documentation](https://martendb.io/events/storage.html#database-tables)

  ### Differences
    
  MartenDB event records do not support a field for metadata or event tags. 
  By default `__metadata__` and `__tags__` are used, but this may be configured 
  when the database is created.
    
  ```sh
  $ mix fact.create --path tmp/marten-ish \\
      --event-schema marten@1 \\
      --event-schema-options event_metadata=metadata,event_tags=tags
  ```
    
  Additionally, Marten supports `tenant_id` and `mt_dotnet_type` fields, which Fact does not support at this time.

  ### Example
    
  When using `marten@1`, persisted event records will take the following shape, with the caveat that
  `__metadata__` and `__tags__` may differ if configured to something else.

  ```js
  {
    "data": {name: "Turts"},
    "id": "3bb4808303c847fd9ceb0a1251ef95da",
    "__metadata__": {"correlationId": "240d3c0e-3251-4076-a769-97a6a705533e"},
    "__tags__": ["turtle:1"],
    "type": "egg_hatched",
    "seq_id": "2",
    "timestamp": 1765039106962264,
    "stream_id": "turtle-1",
    "version": 1,
  }
  ```
    
  """
  @moduledoc since: "0.2.0"
  use Fact.Seam.EventSchema,
    family: :marten,
    version: 1

  import Fact.Seam.Parsers, only: [parse_field_name: 1]

  @typedoc """
  Configuration options for the Marten event schema.
  """
  @typedoc since: "0.2.0"
  @type t() :: %__MODULE__{
          event_metadata: String.t(),
          event_tags: String.t()
        }

  @default_event_metadata "__metadata__"
  @default_event_tags "__tags__"

  @enforce_keys [:event_metadata, :event_tags]
  defstruct [:event_metadata, :event_tags]

  @doc """
  Gets the default options.
  """
  @doc since: "0.2.0"
  @impl true
  @spec default_options() :: t()
  def default_options(),
    do: %{event_metadata: @default_event_metadata, event_tags: @default_event_tags}

  @doc """
  Gets the specification for the configuration options. 
  """
  @doc since: "0.2.0"
  @impl true
  def option_specs() do
    %{
      event_metadata: %{
        allowed: :any,
        parse: &parse_field_name/1,
        error: :invalid_event_metadata
      },
      event_tags: %{
        allowed: :any,
        parse: &parse_field_name/1,
        error: :invalid_event_tags
      }
    }
  end

  @doc """
  Gets a map of the keys used for MartenDB-like event records.
  """
  @doc since: "0.2.0"
  @spec get(t(), keyword()) :: Fact.event_record_schema()
  @impl true
  def get(%__MODULE__{event_metadata: event_metadata, event_tags: event_tags}, opts)
      when is_list(opts) do
    %{
      event_data: "data",
      event_id: "id",
      event_metadata: event_metadata,
      event_tags: event_tags,
      event_type: "type",
      event_store_position: "seq_id",
      event_store_timestamp: "timestamp",
      event_stream_id: "stream_id",
      event_stream_position: "version"
    }
  end
end
