defmodule Fact.RecordSchemaFormat.Default.V1 do
  @behaviour Fact.RecordSchemaFormat

  defstruct []

  @impl true
  def id(), do: :default

  @impl true
  def version(), do: 1

  @impl true
  def metadata(), do: %{}

  @impl true
  def init(_metadata), do: %__MODULE__{}

  @impl true
  def normalize_options(%{} = _options), do: {:ok, %{}}

  @impl true
  def event_data(_format, record), do: record["event_data"]

  @impl true
  def event_id(_format, record), do: record["event_id"]

  @impl true
  def event_metadata(_format, record), do: record["event_metadata"]

  @impl true
  def event_tags(_format, record), do: record["event_tags"]

  @impl true
  def event_type(_format, record), do: record["event_type"]

  @impl true
  def event_store_position(_format, record), do: record["store_position"]

  @impl true
  def event_store_timestamp(_format, record), do: record["store_timestamp"]

  @impl true
  def event_stream_id(_format, record), do: record["stream_id"]

  @impl true
  def event_stream_position(_format, record), do: record["stream_position"]
end
