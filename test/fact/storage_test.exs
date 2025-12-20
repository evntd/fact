defmodule Fact.StorageTest do
  use ExUnit.Case

  alias Fact.TestHelper
  alias Fact.Storage

  @moduletag :capture_log

  # doctest Storage

  setup_all do
    path = TestHelper.create("query", :all_indexers)
    on_exit(fn -> TestHelper.rm_rf(path) end)

    {:ok, instance} = Fact.open(path)

    Fact.append(instance, [
      %{id: e1 = Fact.Uuid.v4(), type: "TestEvent1"},
      %{id: e2 = Fact.Uuid.v4(), type: "TestEvent2"},
      %{id: e3 = Fact.Uuid.v4(), type: "TestEvent3"}
    ])

    {:ok, instance: instance, event_ids: {e1, e2, e3}}
  end

  describe "Fact.Storage.read_ledger/2" do
    test "direction: :invalid, should fail", %{instance: instance} do
      assert_raise Fact.DatabaseError, "invalid read direction: invalid", fn ->
        Storage.read_ledger(instance, direction: :invalid)
      end
    end

    test "direction: :forward, position: :start, count: :all", %{
      instance: instance,
      event_ids: {e1, e2, e3}
    } do
      read_result =
        Storage.read_ledger(instance,
          direction: :forward,
          position: :start,
          count: :all,
          return_type: :record_id
        )
        |> Enum.to_list()

      assert read_result == [e1, e2, e3]
    end

    test "direction: :forward, position: position -1, count: :all, should fail", %{
      instance: instance,
      event_ids: {_e1, _e2, _e3}
    } do
      assert_raise Fact.DatabaseError, "invalid read position: -1", fn ->
        Storage.read_ledger(instance,
          direction: :forward,
          position: -1,
          count: :all,
          return_type: :record_id
        )
        |> Enum.to_list()
      end
    end

    test "direction: :forward, position: position 0, count: :all", %{
      instance: instance,
      event_ids: {e1, e2, e3}
    } do
      read_result =
        Storage.read_ledger(instance,
          direction: :forward,
          position: 0,
          count: :all,
          return_type: :record_id
        )
        |> Enum.to_list()

      assert read_result == [e1, e2, e3]
    end

    test "direction: :forward, position: position 1, count: :all", %{
      instance: instance,
      event_ids: {_e1, e2, e3}
    } do
      read_result =
        Storage.read_ledger(instance,
          direction: :forward,
          position: 1,
          count: :all,
          return_type: :record_id
        )
        |> Enum.to_list()

      assert read_result == [e2, e3]
    end

    test "direction: :forward, position: position 2, count: :all", %{
      instance: instance,
      event_ids: {_e1, _e2, e3}
    } do
      read_result =
        Storage.read_ledger(instance,
          direction: :forward,
          position: 2,
          count: :all,
          return_type: :record_id
        )
        |> Enum.to_list()

      assert read_result == [e3]
    end

    test "direction: :forward, position: position 3, count: :all", %{
      instance: instance,
      event_ids: {_e1, _e2, _e3}
    } do
      read_result =
        Storage.read_ledger(instance,
          direction: :forward,
          position: 3,
          count: :all,
          return_type: :record_id
        )
        |> Enum.to_list()

      assert read_result == []
    end

    test "direction: :forward, position: position 4, count: :all", %{
      instance: instance,
      event_ids: {_e1, _e2, _e3}
    } do
      read_result =
        Storage.read_ledger(instance,
          direction: :forward,
          position: 4,
          count: :all,
          return_type: :record_id
        )
        |> Enum.to_list()

      assert read_result == []
    end

    test "direction: :forward, position: :end, count: :all", %{
      instance: instance,
      event_ids: {_e1, _e2, _e3}
    } do
      read_result =
        Storage.read_ledger(instance,
          direction: :forward,
          position: :end,
          count: :all,
          return_type: :record_id
        )
        |> Enum.to_list()

      assert read_result == []
    end

    test "direction: :forward, position: :start, count: -1", %{instance: instance} do
      assert_raise Fact.DatabaseError, "invalid read count: -1", fn ->
        Storage.read_ledger(instance,
          direction: :forward,
          position: :start,
          count: -1,
          return_type: :record_id
        )
        |> Enum.to_list()
      end
    end

    test "direction: :forward, position: :start, count: 0", %{instance: instance} do
      read_result =
        Storage.read_ledger(instance,
          direction: :forward,
          position: :start,
          count: 0,
          return_type: :record_id
        )
        |> Enum.to_list()

      assert read_result == []
    end

    test "direction: :forward, position: :start, count: 1", %{
      instance: instance,
      event_ids: {e1, _e2, _e3}
    } do
      read_result =
        Storage.read_ledger(instance,
          direction: :forward,
          position: :start,
          count: 1,
          return_type: :record_id
        )
        |> Enum.to_list()

      assert read_result == [e1]
    end

    test "direction: :forward, position: :start, count: 2", %{
      instance: instance,
      event_ids: {e1, e2, _e3}
    } do
      read_result =
        Storage.read_ledger(instance,
          direction: :forward,
          position: :start,
          count: 2,
          return_type: :record_id
        )
        |> Enum.to_list()

      assert read_result == [e1, e2]
    end

    test "direction: :forward, position: :start, count: 3", %{
      instance: instance,
      event_ids: {e1, e2, e3}
    } do
      read_result =
        Storage.read_ledger(instance,
          direction: :forward,
          position: :start,
          count: 3,
          return_type: :record_id
        )
        |> Enum.to_list()

      assert read_result == [e1, e2, e3]
    end

    test "direction: :forward, position: :start, count: 4", %{
      instance: instance,
      event_ids: {e1, e2, e3}
    } do
      read_result =
        Storage.read_ledger(instance,
          direction: :forward,
          position: :start,
          count: 4,
          return_type: :record_id
        )
        |> Enum.to_list()

      assert read_result == [e1, e2, e3]
    end

    test "direction: :forward, position: 1, count: 0", %{instance: instance} do
      read_result =
        Storage.read_ledger(instance,
          direction: :forward,
          position: 1,
          count: 0,
          return_type: :record_id
        )
        |> Enum.to_list()

      assert read_result == []
    end

    test "direction: :forward, position: 1, count: 1", %{
      instance: instance,
      event_ids: {_e1, e2, _e3}
    } do
      read_result =
        Storage.read_ledger(instance,
          direction: :forward,
          position: 1,
          count: 1,
          return_type: :record_id
        )
        |> Enum.to_list()

      assert read_result == [e2]
    end

    test "direction: :forward, position: 1, count: 2", %{
      instance: instance,
      event_ids: {_e1, e2, e3}
    } do
      read_result =
        Storage.read_ledger(instance,
          direction: :forward,
          position: 1,
          count: 2,
          return_type: :record_id
        )
        |> Enum.to_list()

      assert read_result == [e2, e3]
    end

    test "direction: :forward, position: 1, count: 3", %{
      instance: instance,
      event_ids: {_e1, e2, e3}
    } do
      read_result =
        Storage.read_ledger(instance,
          direction: :forward,
          position: 1,
          count: 3,
          return_type: :record_id
        )
        |> Enum.to_list()

      assert read_result == [e2, e3]
    end

    test "direction: :backward, position: :start, count: :all", %{
      instance: instance,
      event_ids: {_e1, _e2, _e3}
    } do
      read_result =
        Storage.read_ledger(instance,
          direction: :backward,
          position: :start,
          count: :all,
          return_type: :record_id
        )
        |> Enum.to_list()

      assert read_result == []
    end

    test "direction: :backward, position: position -1, count: :all", %{
      instance: instance,
      event_ids: {_e1, _e2, _e3}
    } do
      assert_raise Fact.DatabaseError, "invalid read position: -1", fn ->
        Storage.read_ledger(instance,
          direction: :backward,
          position: -1,
          count: :all,
          return_type: :record_id
        )
        |> Enum.to_list()
      end
    end

    test "direction: :backward, position: position 0, count: :all", %{
      instance: instance,
      event_ids: {_e1, _e2, _e3}
    } do
      read_result =
        Storage.read_ledger(instance,
          direction: :backward,
          position: 0,
          count: :all,
          return_type: :record_id
        )
        |> Enum.to_list()

      assert read_result == []
    end

    test "direction: :backward, position: position 1, count: :all", %{
      instance: instance,
      event_ids: {e1, _e2, _e3}
    } do
      read_result =
        Storage.read_ledger(instance,
          direction: :backward,
          position: 1,
          count: :all,
          return_type: :record_id
        )
        |> Enum.to_list()

      assert read_result == [e1]
    end

    test "direction: :backward, position: position 2, count: :all", %{
      instance: instance,
      event_ids: {e1, e2, _e3}
    } do
      read_result =
        Storage.read_ledger(instance,
          direction: :backward,
          position: 2,
          count: :all,
          return_type: :record_id
        )
        |> Enum.to_list()

      assert read_result == [e2, e1]
    end

    test "direction: :backward, position: position 3, count: :all", %{
      instance: instance,
      event_ids: {e1, e2, e3}
    } do
      read_result =
        Storage.read_ledger(instance,
          direction: :backward,
          position: 3,
          count: :all,
          return_type: :record_id
        )
        |> Enum.to_list()

      assert read_result == [e3, e2, e1]
    end

    test "direction: :backward, position: position 4, count: :all", %{
      instance: instance,
      event_ids: {e1, e2, e3}
    } do
      read_result =
        Storage.read_ledger(instance,
          direction: :backward,
          position: 4,
          count: :all,
          return_type: :record_id
        )
        |> Enum.to_list()

      assert read_result == [e3, e2, e1]
    end

    test "direction: :backward, position: :end, count: :all", %{
      instance: instance,
      event_ids: {e1, e2, e3}
    } do
      read_result =
        Storage.read_ledger(instance,
          direction: :backward,
          position: :end,
          count: :all,
          return_type: :record_id
        )
        |> Enum.to_list()

      assert read_result == [e3, e2, e1]
    end

    test "direction: :backward, position: :start, count: -1", %{
      instance: instance,
      event_ids: {_e1, _e2, _e3}
    } do
      assert_raise Fact.DatabaseError, "invalid read count: -1", fn ->
        Storage.read_ledger(instance,
          direction: :backward,
          position: :start,
          count: -1,
          return_type: :record_id
        )
        |> Enum.to_list()
      end
    end

    test "direction: :backward, position: :start, count: 0", %{
      instance: instance,
      event_ids: {_e1, _e2, _e3}
    } do
      read_result =
        Storage.read_ledger(instance,
          direction: :backward,
          position: :start,
          count: 0,
          return_type: :record_id
        )
        |> Enum.to_list()

      assert read_result == []
    end

    test "direction: :backward, position: :end, count: 0", %{
      instance: instance,
      event_ids: {_e1, _e2, _e3}
    } do
      read_result =
        Storage.read_ledger(instance,
          direction: :backward,
          position: :end,
          count: 0,
          return_type: :record_id
        )
        |> Enum.to_list()

      assert read_result == []
    end

    test "direction: :backward, position: :start, count: 1", %{
      instance: instance,
      event_ids: {_e1, _e2, _e3}
    } do
      read_result =
        Storage.read_ledger(instance,
          direction: :backward,
          position: :start,
          count: 1,
          return_type: :record_id
        )
        |> Enum.to_list()

      assert read_result == []
    end

    test "direction: :backward, position: :end, count: 1", %{
      instance: instance,
      event_ids: {_e1, _e2, e3}
    } do
      read_result =
        Storage.read_ledger(instance,
          direction: :backward,
          position: :end,
          count: 1,
          return_type: :record_id
        )
        |> Enum.to_list()

      assert read_result == [e3]
    end

    test "direction: :backward, position: :start, count: 2", %{
      instance: instance,
      event_ids: {_e1, _e2, _e3}
    } do
      read_result =
        Storage.read_ledger(instance,
          direction: :backward,
          position: :start,
          count: 2,
          return_type: :record_id
        )
        |> Enum.to_list()

      assert read_result == []
    end

    test "direction: :backward, position: :end, count: 2", %{
      instance: instance,
      event_ids: {_e1, e2, e3}
    } do
      read_result =
        Storage.read_ledger(instance,
          direction: :backward,
          position: :end,
          count: 2,
          return_type: :record_id
        )
        |> Enum.to_list()

      assert read_result == [e3, e2]
    end

    test "direction: :backward, position: :start, count: 3", %{
      instance: instance,
      event_ids: {_e1, _e2, _e3}
    } do
      read_result =
        Storage.read_ledger(instance,
          direction: :backward,
          position: :start,
          count: 3,
          return_type: :record_id
        )
        |> Enum.to_list()

      assert read_result == []
    end

    test "direction: :backward, position: :end, count: 3", %{
      instance: instance,
      event_ids: {e1, e2, e3}
    } do
      read_result =
        Storage.read_ledger(instance,
          direction: :backward,
          position: :end,
          count: 3,
          return_type: :record_id
        )
        |> Enum.to_list()

      assert read_result == [e3, e2, e1]
    end

    test "direction: :backward, position: :start, count: 4", %{
      instance: instance,
      event_ids: {_e1, _e2, _e3}
    } do
      read_result =
        Storage.read_ledger(instance,
          direction: :backward,
          position: :start,
          count: 4,
          return_type: :record_id
        )
        |> Enum.to_list()

      assert read_result == []
    end

    test "direction: :backward, position: :end, count: 4", %{
      instance: instance,
      event_ids: {e1, e2, e3}
    } do
      read_result =
        Storage.read_ledger(instance,
          direction: :backward,
          position: :end,
          count: 4,
          return_type: :record_id
        )
        |> Enum.to_list()

      assert read_result == [e3, e2, e1]
    end

    test "direction: :backward, position: 2, count: 0", %{
      instance: instance,
      event_ids: {_e1, _e2, _e3}
    } do
      read_result =
        Storage.read_ledger(instance,
          direction: :backward,
          position: 2,
          count: 0,
          return_type: :record_id
        )
        |> Enum.to_list()

      assert read_result == []
    end

    test "direction: :backward, position: 2, count: 1", %{
      instance: instance,
      event_ids: {_e1, e2, _e3}
    } do
      read_result =
        Storage.read_ledger(instance,
          direction: :backward,
          position: 2,
          count: 1,
          return_type: :record_id
        )
        |> Enum.to_list()

      assert read_result == [e2]
    end

    test "direction: :backward, position: 1, count: 2", %{
      instance: instance,
      event_ids: {e1, e2, _e3}
    } do
      read_result =
        Storage.read_ledger(instance,
          direction: :backward,
          position: 2,
          count: 2,
          return_type: :record_id
        )
        |> Enum.to_list()

      assert read_result == [e2, e1]
    end

    test "direction: :backward, position: 1, count: 3", %{
      instance: instance,
      event_ids: {e1, e2, _e3}
    } do
      read_result =
        Storage.read_ledger(instance,
          direction: :backward,
          position: 2,
          count: 3,
          return_type: :record_id
        )
        |> Enum.to_list()

      assert read_result == [e2, e1]
    end
  end
end
