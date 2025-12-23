defmodule Fact.RecordFileName.Registry do
  use Fact.SeamRegistry,
    default: {:event_id, 1},
    formats: [
      Fact.RecordFileName.EventId.V1,
      Fact.RecordFileName.ContentAddressable.V1
    ]
end
