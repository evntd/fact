defmodule TestHelper do
  require Logger

  @doc """
  Test helper method to create a database with a random name.
  """
  def create_db(name_prefix) do
    path =
      :uuid.get_v4()
      |> :uuid.uuid_to_string(:nodash)
      |> to_string()
      |> then(fn uuid -> name_prefix <> uuid end)
      |> String.downcase()
      |> String.split_at(63)
      |> then(fn {name, _} -> Path.join("tmp", name) end)

    Mix.Tasks.Fact.Create.run(["--path", path])

    path
  end

  @doc """
  Helper method to delete the database files, used in on_exit callbacks.
  """
  def rm_rf(path) do
    case File.rm_rf(path) do
      {:ok, _} ->
        :ok

      {:error, reason, _} ->
        Logger.warning("failed to clean up database reason=#{reason} path=#{path}")
        :ok
    end
  end

  @doc """
  Subscribes to the database and waits for all the indexers to index events
  up to the specified position. 
    
  This uses a really naive approach when waiting, it just expects to receive
  some message with the timeout window, then waits again resetting the time
  window, a continues until the expected message is received.
  """
  def subscribe_and_wait(db, position, timeout \\ 10_000) do
    Fact.Database.subscribe(db)
    wait_for_indexing_to_reach(position, timeout)
  end

  defp wait_for_indexing_to_reach(position, timeout) do
    receive do
      {:indexed, pos} when pos >= position ->
        :ok

      true ->
        wait_for_indexing_to_reach(position, timeout)
    after
      timeout ->
        raise "timed out waiting for indexing to reach #{position}"
    end
  end
end

ExUnit.start()
