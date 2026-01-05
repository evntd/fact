defmodule Fact.Event do
  defmodule Id do
    use Fact.Seam.EventId.Adapter,
      context: :event_id
  end

  defmodule Schema do
    use Fact.Seam.EventSchema.Adapter,
      context: :event_schema
  end
end
