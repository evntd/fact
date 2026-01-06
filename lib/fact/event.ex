defmodule Fact.Event do
  defmodule Id do
    use Fact.Seam.EventId.Adapter,
      context: :event_id
  end

  defmodule Schema do
    use Fact.Seam.EventSchema.Adapter,
      context: :event_schema
      
    def get(database_id) do
      with {:ok, context} <- Fact.Registry.get_context(database_id) do
        %{
          event_data: event_data(context),
          event_id: event_id(context),
          event_metadata: event_metadata(context),
          event_tags: event_tags(context),
          event_type: event_type(context),
          event_store_position: event_store_position(context),
          event_store_timestamp: event_store_timestamp(context)
        }
      end
    end
  end
end
