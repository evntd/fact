defmodule Fact.AppendConditionRaceTest do
  use ExUnit.Case

  @moduletag :capture_log

  setup do
    path = TestHelper.create_db("fact_race_")
    on_exit(fn -> TestHelper.rm_rf(path) end)
    {:ok, db} = Fact.open(path)

    {:ok, pos} = Fact.append(db, %{type: "Seeded", tags: ["seed"]})
    TestHelper.subscribe_and_wait(db, pos)

    {:ok, db: db, read_pos: pos}
  end

  test "a second append guarded by the same condition is rejected before indexing catches up",
       %{db: db, read_pos: read_pos} do
    results =
      for n <- 1..20 do
        code = "code:ABC#{n}"
        condition = {Fact.QueryItem.tags(code), read_pos}
        first = Fact.append(db, %{type: "CodeClaimed", tags: [code]}, condition)
        second = Fact.append(db, %{type: "CodeClaimed", tags: [code]}, condition)
        {first, second}
      end

    accepted_twice = Enum.count(results, &match?({{:ok, _}, {:ok, _}}, &1))
    assert accepted_twice == 0, "#{accepted_twice}/20 duplicate claims were accepted"
  end

  test "only one of many concurrent appends guarded by the same condition is accepted",
       %{db: db, read_pos: read_pos} do
    condition = {Fact.QueryItem.tags("code:XYZ"), read_pos}

    results =
      1..50
      |> Task.async_stream(fn _ ->
        Fact.append(db, %{type: "CodeClaimed", tags: ["code:XYZ"]}, condition)
      end)
      |> Enum.map(fn {:ok, result} -> result end)

    assert Enum.count(results, &match?({:ok, _}, &1)) == 1
    assert Enum.count(results, &match?({:error, %Fact.ConcurrencyError{}}, &1)) == 49
  end

  test "await_indexed reports a timeout when the indexers never reach the position",
       %{db: db, read_pos: read_pos} do
    assert :ok = Fact.Database.await_indexed(db, read_pos, 1000)
    assert {:error, :index_timeout} = Fact.Database.await_indexed(db, read_pos + 1, 50)
  end
end
