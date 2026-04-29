defmodule Fact.CatchUpSubscriptionTest do
  use ExUnit.Case

  @moduletag :capture_log

  setup_all do
    Code.ensure_loaded!(Fact.EventDataIndexer)
    path = TestHelper.create_db("sub_test_")
    on_exit(fn -> TestHelper.rm_rf(path) end)
    {:ok, db} = Fact.open(path)

    events = [
      %{stream_id: "sub-s1", type: "TypeA", data: %{"v" => 1}, tags: ["tag1"]},
      %{stream_id: "sub-s1", type: "TypeB", data: %{"v" => 2}, tags: ["tag2"]},
      %{stream_id: "sub-s2", type: "TypeA", data: %{"v" => 3}, tags: ["tag1"]}
    ]

    {:ok, _} = Fact.append(db, events)
    TestHelper.subscribe_and_wait(db, 4)

    {:ok, db: db}
  end

  describe "All subscription" do
    test "from :start replays historical events then catches up", %{db: db} do
      {:ok, _sub} = Fact.subscribe(db, :all, position: :start, subscriber: self())

      # Should receive historical events, then :caught_up
      events = collect_events_until_caught_up(5_000)
      assert length(events) >= 3
    end

    test "from :end skips replay and receives only live events", %{db: db} do
      {:ok, _sub} = Fact.subscribe(db, :all, position: :end, subscriber: self())

      assert_receive :caught_up, 5_000

      # Append a new event
      {:ok, _} = Fact.append(db, [%{stream_id: "sub-live", type: "LiveEvent", data: %{}}])

      assert_receive {:record, _}, 5_000
    end
  end

  describe "Stream subscription" do
    test "receives only events from the specified stream", %{db: db} do
      {:ok, _sub} =
        Fact.subscribe(db, {:stream, "sub-s1"}, position: :start, subscriber: self())

      events = collect_events_until_caught_up(5_000)

      assert length(events) == 2

      assert Enum.all?(events, fn {_rid, event} ->
               event["stream_id"] == "sub-s1"
             end)
    end
  end

  describe "Query subscription" do
    test "receives only events matching the query", %{db: db} do
      query = Fact.QueryItem.types("TypeA")

      {:ok, _sub} =
        Fact.subscribe(db, {:query, query}, position: :start, subscriber: self())

      events = collect_events_until_caught_up(5_000)

      assert length(events) >= 2

      assert Enum.all?(events, fn {_rid, event} ->
               event["event_type"] == "TypeA"
             end)
    end
  end

  defp collect_events_until_caught_up(timeout) do
    collect_events_until_caught_up(timeout, [])
  end

  defp collect_events_until_caught_up(timeout, acc) do
    receive do
      :caught_up ->
        Enum.reverse(acc)

      {:record, record} ->
        collect_events_until_caught_up(timeout, [record | acc])
    after
      timeout ->
        raise "timed out waiting for :caught_up"
    end
  end
end
