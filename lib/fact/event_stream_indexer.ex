defmodule Fact.EventStreamIndexer do
  use Fact.EventIndexer

  @impl true
  def index_event(event, _opts), do: event[@event_stream]

  def last_stream_position(instance, event_stream) do
    last_record_id =
      Fact.Storage.read_index(instance, __MODULE__, event_stream, direction: :backward)
      |> Enum.at(0, :none)

    case last_record_id do
      :none ->
        0

      record_id ->
        {_, event} = Fact.Storage.read_event(instance, record_id)
        event[@event_stream_position]
    end
  end
end
