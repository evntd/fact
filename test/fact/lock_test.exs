defmodule Fact.LockTest do
  use ExUnit.Case

  alias Fact.Lock
  alias Fact.TestHelper

  @moduletag capture_log: true

  setup_all do
    path = TestHelper.create("test-append", :all_indexers)
    on_exit(fn -> TestHelper.rm_rf(path) end)
    {:ok, instance} = Fact.open(path)
    {:ok, instance: instance}
  end

  test "should fail to acquire lock of running instance", %{instance: instance} do
    assert {:error, reason} = Lock.acquire(instance, :run)
    assert {:locked, metadata} = reason
    assert "run" == metadata["mode"]
    assert System.pid() === metadata["os_pid"]
  end

  test "stopping the Fact.LockOwner should release the lock", %{instance: instance} do
    lock_owner = Fact.Instance.via(instance, Fact.LockOwner)

    {:ok, lock1} = Lock.info(instance)

    GenServer.stop(lock_owner, :normal)

    # so it will be either be unlocked, 
    # or the supervisor will have restarted it
    # acquiring a new lock
    {:ok, lock2} = Lock.info(instance)

    # either way, these two lock bindings should be different

    assert lock1 !== lock2
  end
end
