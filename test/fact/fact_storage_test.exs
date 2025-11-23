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

  test "should create an 'events' subdirectory within named instance directory of .fact", %{
    instance: inst
  } do
    expected_dir = ".fact/#{inst}/events"
    Fact.Storage.start_link(instance: inst)
    assert true == File.exists?(expected_dir)
    File.rm_rf!(".fact/#{inst}")
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
end
