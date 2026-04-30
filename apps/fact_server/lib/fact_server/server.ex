defmodule FactServer.Server do
  use GRPC.Server, service: Fact.V1.FactService.Service

  alias Fact.V1.{
    AppendResponse,
    EventRecord,
    SubscribeEvent
  }

  def append(%Fact.V1.AppendRequest{events: events, condition: condition}, _stream) do
    fact_events = Enum.map(events, &to_fact_event/1)
    fact_condition = to_fact_condition(condition)
    handle_append_result(Fact.append(database_id(), fact_events, fact_condition))
  end

  def append_stream(
        %Fact.V1.AppendStreamRequest{
          events: events,
          stream_id: stream_id,
          expected: expected
        },
        _stream
      ) do
    fact_events = Enum.map(events, &to_fact_event/1)
    fact_expectation = to_fact_expectation(expected)

    handle_append_result(
      Fact.append_stream(database_id(), fact_events, stream_id, fact_expectation)
    )
  end

  defp handle_append_result({:ok, position}), do: %AppendResponse{position: position}

  defp handle_append_result({:error, %Fact.ConcurrencyError{} = err}) do
    raise GRPC.RPCError,
      status: GRPC.Status.failed_precondition(),
      message: "concurrency conflict: #{inspect(err)}"
  end

  defp handle_append_result({:error, reason}) do
    raise GRPC.RPCError,
      status: GRPC.Status.internal(),
      message: "append failed: #{inspect(reason)}"
  end

  def read(%Fact.V1.ReadRequest{source: source, options: opts}, stream) do
    db = database_id()
    fact_source = to_fact_source(source)
    fact_opts = to_fact_read_opts(opts)
    schema = Fact.Event.Schema.get(db)

    db
    |> Fact.read(fact_source, fact_opts)
    |> Enum.each(fn {record_id, event_record} ->
      GRPC.Server.send_reply(stream, to_proto_record(record_id, event_record, schema))
    end)
  end

  # ─── Subscribe ────────────────────────────────────────────────────────────────

  def subscribe(
        %Fact.V1.SubscribeRequest{
          source: source,
          start_position: start_pos
        },
        stream
      ) do
    db = database_id()
    fact_source = to_fact_source(source)
    fact_pos = to_fact_position(start_pos)

    case Fact.subscribe(db, fact_source, position: fact_pos) do
      {:ok, _sub_pid} ->
        schema = Fact.Event.Schema.get(db)
        subscribe_loop(stream, schema)

      {:error, reason} ->
        raise GRPC.RPCError,
          status: GRPC.Status.internal(),
          message: "subscribe failed: #{inspect(reason)}"
    end
  end

  defp subscribe_loop(stream, schema) do
    receive do
      {:record, {record_id, event_record}} ->
        proto = to_proto_record(record_id, event_record, schema)
        GRPC.Server.send_reply(stream, %SubscribeEvent{payload: {:record, proto}})
        subscribe_loop(stream, schema)

      :caught_up ->
        GRPC.Server.send_reply(stream, %SubscribeEvent{payload: {:caught_up, true}})
        subscribe_loop(stream, schema)
    end
  end

  defp database_id, do: :persistent_term.get({FactServer, :database_id})

  defp to_fact_event(%Fact.V1.Event{type: type, data: data, metadata: metadata, tags: tags}) do
    %{type: type}
    |> maybe_put(:data, data, &JSON.decode!/1, "")
    |> maybe_put(:metadata, metadata, &JSON.decode!/1, "")
    |> maybe_put(:tags, tags, & &1, [])
  end

  defp maybe_put(map, _key, default, _fun, default), do: map
  defp maybe_put(map, key, value, fun, _default), do: Map.put(map, key, fun.(value))

  defp to_fact_condition(nil), do: nil

  defp to_fact_condition(%Fact.V1.AppendCondition{
         fail_if_events_match: query,
         after_position: after_pos
       }) do
    fact_query = to_fact_query(query)

    case after_pos do
      nil -> fact_query
      pos -> {fact_query, after_position: pos}
    end
  end

  defp to_fact_expectation(nil), do: :any
  defp to_fact_expectation(%Fact.V1.StreamExpectation{value: {:any, _}}), do: :any
  defp to_fact_expectation(%Fact.V1.StreamExpectation{value: {:none, _}}), do: :none
  defp to_fact_expectation(%Fact.V1.StreamExpectation{value: {:exists, _}}), do: :exists
  defp to_fact_expectation(%Fact.V1.StreamExpectation{value: {:position, n}}), do: n

  defp to_fact_source(nil), do: :all
  defp to_fact_source(%Fact.V1.ReadSource{source: {:all, _}}), do: :all
  defp to_fact_source(%Fact.V1.ReadSource{source: {:stream, id}}), do: {:stream, id}

  defp to_fact_source(%Fact.V1.ReadSource{
         source: {:index, %Fact.V1.IndexSource{indexer_id: id, index_value: v}}
       }) do
    {:index, to_fact_indexer_id(id), v}
  end

  defp to_fact_source(%Fact.V1.ReadSource{source: {:query, query}}) do
    {:query, to_fact_query(query)}
  end

  defp to_fact_query(nil), do: :all

  defp to_fact_query(%Fact.V1.Query{items: []}), do: :all

  defp to_fact_query(%Fact.V1.Query{items: items}) do
    items
    |> Enum.map(&to_fact_query_item/1)
    |> Fact.QueryItem.join()
  end

  defp to_fact_query_item(%Fact.V1.QueryItem{types: [], tags: []}) do
    Fact.QueryItem.all()
  end

  defp to_fact_query_item(%Fact.V1.QueryItem{types: types, tags: tags}) do
    q = %Fact.QueryItem{}
    q = if types != [], do: Fact.QueryItem.types(q, types), else: q
    q = if tags != [], do: Fact.QueryItem.tags(q, tags), else: q
    q
  end

  defp to_fact_indexer_id("type"), do: {Fact.EventTypeIndexer, nil}
  defp to_fact_indexer_id("tags"), do: {Fact.EventTagsIndexer, nil}
  defp to_fact_indexer_id("stream"), do: {Fact.EventStreamIndexer, nil}
  defp to_fact_indexer_id("stream_category"), do: {Fact.EventStreamCategoryIndexer, nil}
  defp to_fact_indexer_id("streams"), do: {Fact.EventStreamsIndexer, nil}
  defp to_fact_indexer_id("streams_by_category"), do: {Fact.EventStreamsByCategoryIndexer, nil}

  defp to_fact_indexer_id(id) do
    raise GRPC.RPCError,
      status: GRPC.Status.invalid_argument(),
      message: "unknown indexer_id: #{id}"
  end

  defp to_fact_read_opts(nil), do: [result: :record]

  defp to_fact_read_opts(%Fact.V1.ReadOptions{direction: dir, position: pos, count: count}) do
    direction = if dir == "backward", do: :backward, else: :forward

    opts = [result: :record, direction: direction, position: to_fact_position(pos)]
    if count, do: [{:count, count} | opts], else: opts
  end

  defp to_fact_position(nil), do: :start
  defp to_fact_position(%Fact.V1.ReadPosition{value: {:start, _}}), do: :start
  defp to_fact_position(%Fact.V1.ReadPosition{value: {:from_end, _}}), do: :end
  defp to_fact_position(%Fact.V1.ReadPosition{value: {:position, n}}), do: n
  defp to_fact_position(%Fact.V1.ReadPosition{value: nil}), do: :start

  defp to_proto_record(record_id, event_record, schema) do
    %EventRecord{
      record_id: record_id,
      event_id: Map.get(event_record, schema.event_id, ""),
      event_type: Map.get(event_record, schema.event_type, ""),
      event_data: JSON.encode!(Map.get(event_record, schema.event_data, %{})),
      event_metadata: JSON.encode!(Map.get(event_record, schema.event_metadata, %{})),
      event_tags: Map.get(event_record, schema.event_tags, []),
      event_store_position: Map.get(event_record, schema.event_store_position, 0),
      event_store_timestamp: Map.get(event_record, schema.event_store_timestamp, 0),
      event_stream_id: Map.get(event_record, schema.event_stream_id, ""),
      event_stream_position: Map.get(event_record, schema.event_stream_position, 0)
    }
  end
end
