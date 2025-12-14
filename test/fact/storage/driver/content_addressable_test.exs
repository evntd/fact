defmodule Fact.Storage.Driver.ContentAddressableTest do
  use ExUnit.Case
  use Fact.EventKeys

  setup_all do
    path = "test_cas_" <> Fact.Uuid.v4()
    instance = path |> String.to_atom()

    on_exit(fn -> File.rm_rf!(path) end)

    {:ok, _pid} = Fact.start_link(instance, driver: Fact.Storage.Driver.ContentAddressable)

    {:ok, instance: instance}
  end

  describe "Content Addressable Storage" do
    test "should store appended events in a file name equal to its hashed contents", %{
      instance: db
    } do
      Fact.append(db, %{type: "Test"})
      Process.sleep(50)

      [event] = Fact.read(db, :all) |> Enum.take(1)
      event_hash = :crypto.hash(:sha, Fact.Json.encode!(event)) |> Base.encode16(case: :lower)
      event_path = Path.join(Fact.Storage.events_path(db), event_hash)
      assert File.exists?(event_path)
    end
  end
end
