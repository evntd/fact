#defmodule Fact.CatchUpSubscriptionTest do
#  use ExUnit.Case, async: false
#  use Fact.Types
#
#  @moduletag capture_log: false
#
#  alias Fact.TestHelper
#  alias Fact.CatchUpSubscription
#
#  defmodule TestSubscriber do
#    use GenServer
#
#    def init(_) do
#      state = %{
#        caught_up: false,
#        catchup_events: [],
#        live_events: []
#      }
#
#      {:ok, state}
#    end
#
#    def get_state(pid) do
#      GenServer.call(pid, :get_state)
#    end
#
#    def handle_call(:get_state, _from, state) do
#      {:reply, state, state}
#    end
#
#    def handle_info({:event_record, {_record_id, event}}, %{caught_up: false} = state) do
#      {:noreply, %{state | catchup_events: [event | state.catchup_events]}}
#    end
#
#    def handle_info({:event_record, {_record_id, event}}, %{caught_up: true} = state) do
#      {:noreply, %{state | live_events: [event | state.live_events]}}
#    end
#
#    def handle_info(:caught_up, state) do
#      {:noreply, %{state | caught_up: true}}
#    end
#  end
#
#  @event %{type: "Test"}
#  @stream "stream-1"
#
#  setup_all do
#    path = TestHelper.create("catchup", :all_indexers)
#    on_exit(fn -> TestHelper.rm_rf(path) end)
#    {:ok, db} = Fact.open(path)
#
#    TestHelper.subscribe_to_indexing(db)
#
#    Fact.append(db, @event)
#    Fact.append_stream(db, [@event, @event], @stream)
#
#    TestHelper.wait_for_all_events_to_be_indexed(db)
#
#    {:ok, instance: db}
#  end
#
#  test "subscribed to :all should receive all events", %{instance: db} do
#    CatchUpSubscription.start_link(db, self(), :all, 0)
#
#    assert_receive {:event_record,
#                    {_record_id, %{@event_type => "Test", @event_store_position => 1}}}
#
#    assert_receive {:event_record,
#                    {_record_id,
#                     %{
#                       @event_type => "Test",
#                       @event_store_position => 2,
#                       @event_stream => @stream,
#                       @event_stream_position => 1
#                     }}}
#
#    assert_receive {:event_record,
#                    {_record_id,
#                     %{
#                       @event_type => "Test",
#                       @event_store_position => 3,
#                       @event_stream => @stream,
#                       @event_stream_position => 2
#                     }}}
#
#    assert_receive :caught_up
#  end
#
#  test "subscribed to :all should receive events after start position", %{instance: db} do
#    CatchUpSubscription.start_link(db, self(), :all, 2)
#
#    assert_receive {:event_record,
#                    {_record_id,
#                     %{
#                       @event_type => "Test",
#                       @event_store_position => 3,
#                       @event_stream => @stream,
#                       @event_stream_position => 2
#                     }}}
#
#    assert_receive :caught_up
#  end
#
#  test "subscribed to :all from last position should receive :caught_up", %{instance: db} do
#    CatchUpSubscription.start_link(db, self(), :all, 3)
#    assert_receive :caught_up
#  end
#
#  test "subscribed to :all should receive events after caught up", %{instance: db} do
#    TestHelper.subscribe_to_indexing(db)
#    CatchUpSubscription.start_link(db, self(), :all, 3)
#    assert_receive :caught_up
#
#    Fact.append_stream(db, [@event, @event], @stream)
#    TestHelper.wait_for_all_events_to_be_indexed(db)
#
#    assert_receive {:event_record,
#                    {_record_id,
#                     %{
#                       @event_type => "Test",
#                       @event_store_position => 4,
#                       @event_stream => @stream,
#                       @event_stream_position => 3
#                     }}}
#
#    assert_receive {:event_record,
#                    {_record_id,
#                     %{
#                       @event_type => "Test",
#                       @event_store_position => 5,
#                       @event_stream => @stream,
#                       @event_stream_position => 4
#                     }}}
#  end
#
#  test "subscribed to stream should receive all events", %{instance: db} do
#    CatchUpSubscription.start_link(db, self(), {:stream, @stream}, 0)
#
#    assert_receive {:event_record,
#                    {_record_id,
#                     %{
#                       @event_type => "Test",
#                       @event_store_position => 2,
#                       @event_stream => @stream,
#                       @event_stream_position => 1
#                     }}}
#
#    assert_receive {:event_record,
#                    {_record_id,
#                     %{
#                       @event_type => "Test",
#                       @event_store_position => 3,
#                       @event_stream => @stream,
#                       @event_stream_position => 2
#                     }}}
#
#    assert_receive :caught_up
#  end
#
#  test "subscribed to stream should receive events after start position", %{instance: db} do
#    CatchUpSubscription.start_link(db, self(), {:stream, @stream}, 1)
#
#    assert_receive {:event_record,
#                    {_record_id,
#                     %{
#                       @event_type => "Test",
#                       @event_store_position => 3,
#                       @event_stream => @stream,
#                       @event_stream_position => 2
#                     }}}
#
#    assert_receive :caught_up
#  end
#
#  test "subscribed to stream from last position should receive :caught_up", %{instance: db} do
#    CatchUpSubscription.start_link(db, self(), {:stream, @stream}, 2)
#    assert_receive :caught_up
#  end
#
#  test "subscribed to stream should receive events after caught up", %{instance: db} do
#    TestHelper.subscribe_to_indexing(db)
#    CatchUpSubscription.start_link(db, self(), {:stream, @stream}, 2)
#    assert_receive :caught_up
#
#    Fact.append_stream(db, [@event, @event], @stream)
#    TestHelper.wait_for_all_events_to_be_indexed(db)
#
#    assert_receive {:event_record,
#                    {_record_id,
#                     %{
#                       @event_type => "Test",
#                       @event_store_position => 4,
#                       @event_stream => @stream,
#                       @event_stream_position => 3
#                     }}}
#
#    assert_receive {:event_record,
#                    {_record_id,
#                     %{
#                       @event_type => "Test",
#                       @event_store_position => 5,
#                       @event_stream => @stream,
#                       @event_stream_position => 4
#                     }}}
#  end
#
#  test "stops CatchUpSubscription when subscriber exists", %{instance: db} do
#    {:ok, subscriber} = GenServer.start(TestSubscriber, [], [])
#    {:ok, subscription} = CatchUpSubscription.start_link(db, subscriber, :all, 0)
#
#    Process.exit(subscriber, :kill)
#    Process.sleep(100)
#
#    assert false == Process.alive?(subscription)
#  end
#end
