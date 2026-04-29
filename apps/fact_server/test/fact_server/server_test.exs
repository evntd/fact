defmodule FactServer.ServerTest do
  use ExUnit.Case, async: false

  alias Fact.V1.{
    AppendRequest,
    AppendCondition,
    AppendStreamRequest,
    AppendResponse,
    Event,
    EventRecord,
    FactService,
    Query,
    QueryItem,
    ReadRequest,
    ReadOptions,
    ReadPosition,
    ReadSource,
    StreamExpectation,
    SubscribeEvent,
    SubscribeRequest
  }

  setup_all do
    {:ok, _} = DynamicSupervisor.start_link(strategy: :one_for_one, name: GRPC.Client.Supervisor)
    {:ok, _, port} = GRPC.Server.start_endpoint(FactServer.Endpoint, 0)
    {:ok, channel} = GRPC.Stub.connect("localhost:#{port}")
    on_exit(fn -> GRPC.Server.stop_endpoint(FactServer.Endpoint) end)
    %{channel: channel, port: port}
  end

  setup do
    path = TestHelper.create_db("fact_server_test_")
    {:ok, db} = Fact.open(path)
    on_exit(fn -> Fact.close(db) end)
    on_exit(fn -> TestHelper.rm_rf(path) end)
    %{db: db}
  end

  defp unwrap_stream(stream) do
    Enum.map(stream, fn {:ok, item} -> item end)
  end

  # Starts a subscriber process that owns its own gRPC channel and forwards
  # SubscribeEvent items to the caller's mailbox as {:stream_item, item}.
  # Returns the subscriber pid. Kill it with Process.exit(pid, :kill) when done.
  defp subscribe_async(port, request) do
    test_pid = self()

    spawn(fn ->
      {:ok, ch} = GRPC.Stub.connect("localhost:#{port}")
      {:ok, sub_stream} = FactService.Stub.subscribe(ch, request)

      Enum.each(sub_stream, fn item ->
        send(test_pid, {:stream_item, item})
      end)
    end)
  end

  # ─── Append ────────────────────────────────────────────────────────────────

  describe "Append" do
    test "appends events and returns the last position", %{channel: channel, db: db} do
      events = [
        %Event{type: "order_placed", data: Jason.encode!(%{item: "pizza"}), tags: ["orders"]},
        %Event{type: "order_confirmed"}
      ]

      {:ok, %AppendResponse{position: pos}} =
        FactService.Stub.append(channel, %AppendRequest{database_id: db, events: events})

      # genesis event at 1, two user events at 2 and 3
      assert pos == 3
    end

    test "appending an empty list is a no-op", %{channel: channel, db: db} do
      {:ok, %AppendResponse{position: pos}} =
        FactService.Stub.append(channel, %AppendRequest{database_id: db, events: []})

      assert pos == 1
    end

    test "returns FAILED_PRECONDITION on concurrency conflict", %{channel: channel, db: db} do
      event = %Event{type: "something_happened"}

      {:ok, _} =
        FactService.Stub.append(channel, %AppendRequest{database_id: db, events: [event]})

      TestHelper.subscribe_and_wait(db, 2)

      condition = %AppendCondition{
        fail_if_events_match: %Query{items: [%QueryItem{types: ["something_happened"]}]}
      }

      {:error, %GRPC.RPCError{status: status}} =
        FactService.Stub.append(channel, %AppendRequest{
          database_id: db,
          events: [event],
          condition: condition
        })

      assert status == GRPC.Status.failed_precondition()
    end
  end

  # ─── AppendStream ──────────────────────────────────────────────────────────

  describe "AppendStream" do
    test "appends to a stream and returns the stream position", %{channel: channel, db: db} do
      event = %Event{type: "widget_created", tags: ["widgets"]}

      {:ok, %AppendResponse{position: pos}} =
        FactService.Stub.append_stream(channel, %AppendStreamRequest{
          database_id: db,
          events: [event],
          stream_id: "widget-1",
          expected: %StreamExpectation{value: {:none, true}}
        })

      assert pos == 1
    end

    test "returns FAILED_PRECONDITION when stream expectation fails", %{channel: channel, db: db} do
      event = %Event{type: "widget_created"}

      {:ok, _} =
        FactService.Stub.append_stream(channel, %AppendStreamRequest{
          database_id: db,
          events: [event],
          stream_id: "widget-2",
          expected: %StreamExpectation{value: {:any, true}}
        })

      {:error, %GRPC.RPCError{status: status}} =
        FactService.Stub.append_stream(channel, %AppendStreamRequest{
          database_id: db,
          events: [event],
          stream_id: "widget-2",
          expected: %StreamExpectation{value: {:none, true}}
        })

      assert status == GRPC.Status.failed_precondition()
    end
  end

  # ─── Read ──────────────────────────────────────────────────────────────────

  describe "Read" do
    setup %{db: db} do
      {:ok, pos} =
        Fact.append(db, [
          %{type: "item_added", tags: ["catalog"]},
          %{type: "item_removed", tags: ["catalog"]},
          %{type: "order_placed"}
        ])

      TestHelper.subscribe_and_wait(db, pos)
      :ok
    end

    test "reads all events from the ledger", %{channel: channel, db: db} do
      {:ok, stream} =
        FactService.Stub.read(channel, %ReadRequest{
          database_id: db,
          source: %ReadSource{source: {:all, true}}
        })

      records = unwrap_stream(stream)
      assert length(records) == 4
      assert [%EventRecord{} | _] = records
    end

    test "reads events by type query", %{channel: channel, db: db} do
      {:ok, stream} =
        FactService.Stub.read(channel, %ReadRequest{
          database_id: db,
          source: %ReadSource{
            source: {:query, %Query{items: [%QueryItem{types: ["item_added"]}]}}
          }
        })

      [record] = unwrap_stream(stream)
      assert record.event_type == "item_added"
    end

    test "reads events by tag index", %{channel: channel, db: db} do
      {:ok, stream} =
        FactService.Stub.read(channel, %ReadRequest{
          database_id: db,
          source: %ReadSource{
            source: {:index, %Fact.V1.IndexSource{indexer_id: "tags", index_value: "catalog"}}
          }
        })

      records = unwrap_stream(stream)
      assert length(records) == 2
      assert Enum.all?(records, &("catalog" in &1.event_tags))
    end

    test "respects count option", %{channel: channel, db: db} do
      {:ok, stream} =
        FactService.Stub.read(channel, %ReadRequest{
          database_id: db,
          source: %ReadSource{source: {:all, true}},
          options: %ReadOptions{count: 2}
        })

      assert length(unwrap_stream(stream)) == 2
    end

    test "reads backward from end", %{channel: channel, db: db} do
      {:ok, stream} =
        FactService.Stub.read(channel, %ReadRequest{
          database_id: db,
          source: %ReadSource{source: {:all, true}},
          options: %ReadOptions{
            direction: "backward",
            position: %ReadPosition{value: {:from_end, true}},
            count: 1
          }
        })

      [last] = unwrap_stream(stream)
      assert last.event_type == "order_placed"
    end

    test "event_record fields are populated", %{channel: channel, db: db} do
      {:ok, stream} =
        FactService.Stub.read(channel, %ReadRequest{
          database_id: db,
          source: %ReadSource{source: {:all, true}},
          options: %ReadOptions{count: 1}
        })

      [record] = unwrap_stream(stream)
      assert record.event_id != ""
      assert record.record_id != ""
      assert record.event_store_position > 0
      assert record.event_store_timestamp > 0
    end
  end

  # ─── Subscribe ─────────────────────────────────────────────────────────────
  #
  # Each subscribe test uses subscribe_async/2 which spawns a dedicated process
  # with its own gRPC channel. This is necessary because gun (HTTP/2) sends
  # protocol messages to the channel-owning process, so the reading process must
  # own the channel to avoid leaking gun frames into the test process mailbox.

  describe "Subscribe" do
    test "subscribe from end delivers caught_up then live events", %{
      channel: channel,
      port: port,
      db: db
    } do
      sub_pid =
        subscribe_async(port, %SubscribeRequest{
          database_id: db,
          source: %ReadSource{source: {:all, true}},
          start_position: %ReadPosition{value: {:from_end, true}}
        })

      assert_receive {:stream_item, {:ok, %SubscribeEvent{payload: {:caught_up, true}}}}, 5_000

      {:ok, _} =
        FactService.Stub.append(channel, %AppendRequest{
          database_id: db,
          events: [%Event{type: "live_event"}]
        })

      assert_receive {:stream_item,
                      {:ok,
                       %SubscribeEvent{
                         payload: {:record, %EventRecord{event_type: "live_event"}}
                       }}},
                     5_000

      Process.exit(sub_pid, :kill)
    end

    test "subscribe from a position replays history then delivers live events", %{
      channel: channel,
      port: port,
      db: db
    } do
      {:ok, pre_pos} = Fact.append(db, %{type: "pre_existing"})
      TestHelper.subscribe_and_wait(db, pre_pos)

      sub_pid =
        subscribe_async(port, %SubscribeRequest{
          database_id: db,
          source: %ReadSource{source: {:all, true}},
          start_position: %ReadPosition{value: {:position, pre_pos}}
        })

      assert_receive {:stream_item,
                      {:ok,
                       %SubscribeEvent{
                         payload: {:record, %EventRecord{event_type: "pre_existing"}}
                       }}},
                     5_000

      assert_receive {:stream_item, {:ok, %SubscribeEvent{payload: {:caught_up, true}}}}, 5_000

      {:ok, _} =
        FactService.Stub.append(channel, %AppendRequest{
          database_id: db,
          events: [%Event{type: "live_event"}]
        })

      assert_receive {:stream_item,
                      {:ok,
                       %SubscribeEvent{
                         payload: {:record, %EventRecord{event_type: "live_event"}}
                       }}},
                     5_000

      Process.exit(sub_pid, :kill)
    end

    test "subscribe to a type query delivers only matching events", %{
      channel: channel,
      port: port,
      db: db
    } do
      TestHelper.subscribe_and_wait(db, 1)

      sub_pid =
        subscribe_async(port, %SubscribeRequest{
          database_id: db,
          source: %ReadSource{
            source: {:query, %Query{items: [%QueryItem{types: ["widget_shipped"]}]}}
          },
          start_position: %ReadPosition{value: {:from_end, true}}
        })

      assert_receive {:stream_item, {:ok, %SubscribeEvent{payload: {:caught_up, true}}}}, 5_000

      {:ok, _} =
        FactService.Stub.append(channel, %AppendRequest{
          database_id: db,
          events: [
            %Event{type: "widget_shipped"},
            %Event{type: "other_event"}
          ]
        })

      assert_receive {:stream_item,
                      {:ok,
                       %SubscribeEvent{
                         payload: {:record, %EventRecord{event_type: "widget_shipped"}}
                       }}},
                     5_000

      refute_received {:stream_item,
                       {:ok, %SubscribeEvent{payload: {:record, %EventRecord{event_type: "other_event"}}}}}

      Process.exit(sub_pid, :kill)
    end
  end
end
