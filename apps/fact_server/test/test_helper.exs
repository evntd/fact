defmodule TestHelper do
  require Logger

  def create_db(name_prefix) do
    path =
      :uuid.get_v4()
      |> :uuid.uuid_to_string(:nodash)
      |> to_string()
      |> then(fn uuid -> name_prefix <> uuid end)
      |> String.downcase()
      |> String.split_at(63)
      |> then(fn {name, _} -> Path.join("tmp", name) end)

    Mix.Tasks.Fact.Create.run(["--path", path, "--quiet"])
    path
  end

  def rm_rf(path) do
    case File.rm_rf(path) do
      {:ok, _} -> :ok
      {:error, reason, _} ->
        Logger.warning("failed to clean up database reason=#{reason} path=#{path}")
        :ok
    end
  end

  def subscribe_and_wait(db, position, timeout \\ 10_000) do
    Fact.Database.subscribe(db)
    wait_for_indexing_to_reach(position, timeout)
  end

  defp wait_for_indexing_to_reach(position, timeout) do
    receive do
      {:indexed, pos} when pos >= position -> :ok
      _ -> wait_for_indexing_to_reach(position, timeout)
    after
      timeout -> raise "timed out waiting for indexing to reach #{position}"
    end
  end
end

ExUnit.start()
