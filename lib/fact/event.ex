defmodule Fact.Event do
  @moduledoc """
  Domain-specific module that encapsulates configurable adapters 
  for event-related operations. 
  """

  defmodule Id do
    @moduledoc """
    Adapter for working with configurable event id implementations.
      
    There is currently only a single implementation, see `Fact.Seam.EventId.Uuid.V4`.
    """
    use Fact.Seam.EventId.Adapter,
      context: :event_id
  end

  defmodule Schema do
    @moduledoc """
    Adapter for working with configurable event schema implementations.
      
    There is currently only a single implementation, see `Fact.Seam.EventSchema.Standard.V1`.
    """
    use Fact.Seam.EventSchema.Adapter,
      context: :event_schema
  end
end
