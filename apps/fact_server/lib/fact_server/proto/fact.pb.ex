defmodule Fact.V1.Event do
  @moduledoc false

  use Protobuf, full_name: "fact.v1.Event", protoc_gen_elixir_version: "0.16.0", syntax: :proto3

  field(:type, 1, type: :string)
  field(:data, 2, type: :bytes)
  field(:metadata, 3, type: :bytes)
  field(:tags, 4, repeated: true, type: :string)
end

defmodule Fact.V1.EventRecord do
  @moduledoc false

  use Protobuf,
    full_name: "fact.v1.EventRecord",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field(:event_id, 1, type: :string, json_name: "eventId")
  field(:event_type, 2, type: :string, json_name: "eventType")
  field(:event_data, 3, type: :bytes, json_name: "eventData")
  field(:event_metadata, 4, type: :bytes, json_name: "eventMetadata")
  field(:event_tags, 5, repeated: true, type: :string, json_name: "eventTags")
  field(:event_store_position, 6, type: :uint64, json_name: "eventStorePosition")
  field(:event_store_timestamp, 7, type: :uint64, json_name: "eventStoreTimestamp")
  field(:event_stream_id, 8, type: :string, json_name: "eventStreamId")
  field(:event_stream_position, 9, type: :uint64, json_name: "eventStreamPosition")
  field(:record_id, 10, type: :string, json_name: "recordId")
end

defmodule Fact.V1.QueryItem do
  @moduledoc false

  use Protobuf,
    full_name: "fact.v1.QueryItem",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field(:types, 1, repeated: true, type: :string)
  field(:tags, 2, repeated: true, type: :string)
end

defmodule Fact.V1.Query do
  @moduledoc false

  use Protobuf, full_name: "fact.v1.Query", protoc_gen_elixir_version: "0.16.0", syntax: :proto3

  field(:items, 1, repeated: true, type: Fact.V1.QueryItem)
end

defmodule Fact.V1.ReadSource do
  @moduledoc false

  use Protobuf,
    full_name: "fact.v1.ReadSource",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  oneof(:source, 0)

  field(:all, 1, type: :bool, oneof: 0)
  field(:stream, 2, type: :string, oneof: 0)
  field(:index, 3, type: Fact.V1.IndexSource, oneof: 0)
  field(:query, 4, type: Fact.V1.Query, oneof: 0)
end

defmodule Fact.V1.IndexSource do
  @moduledoc false

  use Protobuf,
    full_name: "fact.v1.IndexSource",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field(:indexer_id, 1, type: :string, json_name: "indexerId")
  field(:index_value, 2, type: :string, json_name: "indexValue")
end

defmodule Fact.V1.AppendRequest do
  @moduledoc false

  use Protobuf,
    full_name: "fact.v1.AppendRequest",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field(:events, 1, repeated: true, type: Fact.V1.Event)
  field(:condition, 2, proto3_optional: true, type: Fact.V1.AppendCondition)
end

defmodule Fact.V1.AppendCondition do
  @moduledoc false

  use Protobuf,
    full_name: "fact.v1.AppendCondition",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field(:fail_if_events_match, 1, type: Fact.V1.Query, json_name: "failIfEventsMatch")
  field(:after_position, 2, proto3_optional: true, type: :uint64, json_name: "afterPosition")
end

defmodule Fact.V1.AppendStreamRequest do
  @moduledoc false

  use Protobuf,
    full_name: "fact.v1.AppendStreamRequest",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field(:events, 1, repeated: true, type: Fact.V1.Event)
  field(:stream_id, 2, type: :string, json_name: "streamId")
  field(:expected, 3, type: Fact.V1.StreamExpectation)
end

defmodule Fact.V1.StreamExpectation do
  @moduledoc false

  use Protobuf,
    full_name: "fact.v1.StreamExpectation",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  oneof(:value, 0)

  field(:any, 1, type: :bool, oneof: 0)
  field(:none, 2, type: :bool, oneof: 0)
  field(:exists, 3, type: :bool, oneof: 0)
  field(:position, 4, type: :uint64, oneof: 0)
end

defmodule Fact.V1.AppendResponse do
  @moduledoc false

  use Protobuf,
    full_name: "fact.v1.AppendResponse",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field(:position, 1, type: :uint64)
end

defmodule Fact.V1.ReadRequest do
  @moduledoc false

  use Protobuf,
    full_name: "fact.v1.ReadRequest",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field(:source, 1, type: Fact.V1.ReadSource)
  field(:options, 2, type: Fact.V1.ReadOptions)
end

defmodule Fact.V1.ReadOptions do
  @moduledoc false

  use Protobuf,
    full_name: "fact.v1.ReadOptions",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field(:direction, 1, type: :string)
  field(:position, 2, type: Fact.V1.ReadPosition)
  field(:count, 3, proto3_optional: true, type: :uint64)
end

defmodule Fact.V1.ReadPosition do
  @moduledoc false

  use Protobuf,
    full_name: "fact.v1.ReadPosition",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  oneof(:value, 0)

  field(:start, 1, type: :bool, oneof: 0)
  field(:from_end, 2, type: :bool, json_name: "fromEnd", oneof: 0)
  field(:position, 3, type: :uint64, oneof: 0)
end

defmodule Fact.V1.SubscribeRequest do
  @moduledoc false

  use Protobuf,
    full_name: "fact.v1.SubscribeRequest",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  field(:source, 1, type: Fact.V1.ReadSource)
  field(:start_position, 2, type: Fact.V1.ReadPosition, json_name: "startPosition")
end

defmodule Fact.V1.SubscribeEvent do
  @moduledoc false

  use Protobuf,
    full_name: "fact.v1.SubscribeEvent",
    protoc_gen_elixir_version: "0.16.0",
    syntax: :proto3

  oneof(:payload, 0)

  field(:record, 1, type: Fact.V1.EventRecord, oneof: 0)
  field(:caught_up, 2, type: :bool, json_name: "caughtUp", oneof: 0)
end

defmodule Fact.V1.FactService.Service do
  @moduledoc false

  use GRPC.Service, name: "fact.v1.FactService", protoc_gen_elixir_version: "0.16.0"

  rpc(:Append, Fact.V1.AppendRequest, Fact.V1.AppendResponse)

  rpc(:AppendStream, Fact.V1.AppendStreamRequest, Fact.V1.AppendResponse)

  rpc(:Read, Fact.V1.ReadRequest, stream(Fact.V1.EventRecord))

  rpc(:Subscribe, Fact.V1.SubscribeRequest, stream(Fact.V1.SubscribeEvent))
end

defmodule Fact.V1.FactService.Stub do
  @moduledoc false

  use GRPC.Stub, service: Fact.V1.FactService.Service
end
