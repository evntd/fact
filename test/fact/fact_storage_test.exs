defmodule Fact.Storage.Test do
  use ExUnit.Case, async: true
  doctest Fact.Storage

  @null <<0>>

  setup_all do
    on_exit(fn -> File.rm_rf!("tmp/Fact.Storage.Test") end)
  end

  setup do
    inst = "test_" <> (DateTime.utc_now() |> DateTime.to_unix() |> to_string())
    {:ok, instance: inst}
  end

  test "should create an 'events' subdirectory within named instance directory", %{
    instance: inst
  } do
    expected_dir = "#{inst}/events"
    Fact.Storage.start_link(instance: inst)
    assert true == File.exists?(expected_dir)
    File.rm_rf!("#{inst}")
  end

  test "should create a '.gitignore' file within the named instance directory", %{
    instance: inst
  } do
    expected_file = "#{inst}/.gitignore"
    Fact.Storage.start_link(instance: inst)
    assert true == File.exists?(expected_file)
    File.rm_rf!("#{inst}")
  end

  @tag :tmp_dir
  test "should create an 'events' subdirectory within supplied path", %{
    instance: inst,
    tmp_dir: path
  } do
    expected_dir = "#{path}/events"
    Fact.Storage.start_link(instance: inst, path: path)
    assert true == File.exists?(expected_dir)
  end

  test "should fail with :badarg when path is invalid", %{instance: inst} do
    invalid_path = "abc" <> @null
    assert {:error, :badarg} = Fact.Storage.start_link(instance: inst, path: invalid_path)
  end

  @tag :tmp_dir
  test "should fail with :nofile when driver module does not exist", %{
    instance: inst,
    tmp_dir: path
  } do
    assert {:error, :nofile} ==
             Fact.Storage.start_link(
               instance: inst,
               path: path,
               driver: Fact.Storage.Driver.DoesNotExist
             )
  end

  @tag :tmp_dir
  test "should fail with :nofile when format module does not exist", %{
    instance: inst,
    tmp_dir: path
  } do
    assert {:error, :nofile} ==
             Fact.Storage.start_link(
               instance: inst,
               path: path,
               format: Fact.Storage.Format.DoesNotExist
             )
  end

  @tag :tmp_dir
  test "should write event into file matching id into 'events' when using `Fact.Storage.Driver.ByEventId`",
       %{
         instance: inst,
         tmp_dir: path
       } do
    Fact.Storage.start_link(instance: inst, path: path, driver: Fact.Storage.Driver.ByEventId)
    event_id = Fact.Uuid.v4()
    expected_file = Path.join([path, "events", event_id])
    event = %{"event_id" => event_id, "event_type" => "TestEvent", "event_data" => %{}, "event_metadata" => %{}}
    Fact.Storage.write_event(inst, event)
    assert true == File.exists?(expected_file)
  end

  @tag :tmp_dir
  test "should not write event when it fails to be prepared", %{instance: inst, tmp_dir: path} do
    Fact.Storage.start_link(instance: inst, path: path, driver: Fact.Storage.Driver.ByEventId)
    event_id = "invalid_event_id"
    unexpected_file = Path.join([path, "events", event_id])
    event = %{"event_id" => event_id, "event_type" => "TestEvent", "event_data" => %{}, "event_metadata" => %{}}
    result = Fact.Storage.write_event(inst, event)
    assert {:error, :invalid_record_id, "invalid_event_id"} == result
    assert false == File.exists?(unexpected_file)
  end
end
