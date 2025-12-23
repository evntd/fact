defmodule Fact.RecordFileFormat.Registry do
  use Fact.SeamRegistry,
    default: {:json, 1},
    formats: [
      Fact.RecordFileFormat.Json.V1
    ]
end
