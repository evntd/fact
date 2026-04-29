defmodule Fact.EventStreamWriterTest do
  use ExUnit.Case

  @moduletag :capture_log

  alias Fact.EventStreamWriter

  setup_all do
    path = TestHelper.create_db("esw_test_")
    on_exit(fn -> TestHelper.rm_rf(path) end)
    {:ok, db} = Fact.open(path)
    {:ok, db: db}
  end

  describe "commit/5" do
    test "single event to a new stream", %{db: db} do
      stream = "esw-stream-#{:erlang.unique_integer([:positive])}"
      event = %{type: "Created", data: %{"x" => 1}}

      assert {:ok, 1} = EventStreamWriter.commit(db, event, stream)
    end

    test "multiple events increment stream position", %{db: db} do
      stream = "esw-multi-#{:erlang.unique_integer([:positive])}"
      events = [%{type: "A"}, %{type: "B"}, %{type: "C"}]

      assert {:ok, 3} = EventStreamWriter.commit(db, events, stream)
    end

    test "with :any expectation always succeeds", %{db: db} do
      stream = "esw-any-#{:erlang.unique_integer([:positive])}"

      assert {:ok, 1} = EventStreamWriter.commit(db, [%{type: "A"}], stream, :any)
      assert {:ok, 2} = EventStreamWriter.commit(db, [%{type: "B"}], stream, :any)
    end

    test "with :none expectation succeeds for new stream", %{db: db} do
      stream = "esw-none-ok-#{:erlang.unique_integer([:positive])}"

      assert {:ok, 1} = EventStreamWriter.commit(db, [%{type: "A"}], stream, :none)
    end

    test "with :none expectation fails for existing stream", %{db: db} do
      stream = "esw-none-fail-#{:erlang.unique_integer([:positive])}"
      EventStreamWriter.commit(db, [%{type: "A"}], stream, :any)

      assert {:error, %Fact.ConcurrencyError{expected: :none}} =
               EventStreamWriter.commit(db, [%{type: "B"}], stream, :none)
    end

    test "with :exists expectation fails for new stream", %{db: db} do
      stream = "esw-exists-fail-#{:erlang.unique_integer([:positive])}"

      assert {:error, %Fact.ConcurrencyError{expected: :exists, actual: 0}} =
               EventStreamWriter.commit(db, [%{type: "A"}], stream, :exists)
    end

    test "with :exists expectation succeeds for existing stream", %{db: db} do
      stream = "esw-exists-ok-#{:erlang.unique_integer([:positive])}"
      EventStreamWriter.commit(db, [%{type: "A"}], stream)

      assert {:ok, 2} = EventStreamWriter.commit(db, [%{type: "B"}], stream, :exists)
    end

    test "with integer expectation succeeds when matching", %{db: db} do
      stream = "esw-int-ok-#{:erlang.unique_integer([:positive])}"
      {:ok, 1} = EventStreamWriter.commit(db, [%{type: "A"}], stream)

      assert {:ok, 2} = EventStreamWriter.commit(db, [%{type: "B"}], stream, 1)
    end

    test "with integer expectation fails when not matching", %{db: db} do
      stream = "esw-int-fail-#{:erlang.unique_integer([:positive])}"
      {:ok, 1} = EventStreamWriter.commit(db, [%{type: "A"}], stream)

      assert {:error, %Fact.ConcurrencyError{expected: 99, actual: 1}} =
               EventStreamWriter.commit(db, [%{type: "B"}], stream, 99)
    end
  end

  describe "commit/5 validation" do
    test "non-list events", %{db: db} do
      assert {:error, :invalid_event_list} =
               EventStreamWriter.commit(db, "not a list", "stream")
    end

    test "non-map events", %{db: db} do
      assert {:error, :invalid_events} =
               EventStreamWriter.commit(db, ["not a map"], "stream")
    end

    test "events missing :type", %{db: db} do
      assert {:error, :missing_event_type} =
               EventStreamWriter.commit(db, [%{data: "no type"}], "stream")
    end

    test "non-binary stream", %{db: db} do
      assert {:error, :invalid_event_stream} =
               EventStreamWriter.commit(db, [%{type: "A"}], 123)
    end

    test "invalid expected_position", %{db: db} do
      assert {:error, :invalid_expected_position} =
               EventStreamWriter.commit(db, [%{type: "A"}], "stream", :invalid)
    end
  end
end
