defmodule Fact.Storage.Driver.ContentAddressableTest do
  use ExUnit.Case
  use Fact.Types

  setup_all do
    name = "test-cas-" <> (DateTime.utc_now() |> DateTime.to_unix() |> to_string())
    path = Path.join("tmp", name)

    Mix.Tasks.Fact.Create.run([
      "--name",
      name,
      "--path",
      path,
      "--quiet",
      "--record-filename-scheme",
      "cas"
    ])

    on_exit(fn -> File.rm_rf!(path) end)

    {:ok, instance} = Fact.open(path)

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
      event_path = Path.join(Fact.Instance.events_path(db), event_hash)
      assert File.exists?(event_path)
    end
  end
end
