defmodule Fact.Seam.FileWriter.Standard.V1Test do
  use ExUnit.Case

  import Bitwise
  
  alias Fact.Seam.FileWriter.Standard.V1

  @moduletag :capture_log

  doctest V1

  test "module exists" do
    assert is_list(V1.module_info())
  end

  describe "id/0" do
    test "should be {:standard, 1}" do
      assert {:standard, 1} == V1.id()
    end
  end

  describe "family/0" do
    test "should be :standard" do
      assert :standard == V1.family()
    end
  end

  describe "version/0" do
    test "should be 1" do
      assert 1 == V1.version()
    end
  end

  describe "default_options/0" do
    test "should provide expected defaults" do
      assert %{access: :write, binary: true, exclusive: true, sync: false, worm: false} =
               V1.default_options()
    end
  end

  describe "init/1" do
    test "given empty map should return defaults as struct with computed modes" do
      %{access: a, binary: b, exclusive: e, sync: s, worm: w} = V1.default_options()

      assert %V1{sync: ^s, worm: ^w, modes: modes} = V1.init(%{})

      assert a in modes
      assert (if b, do: :binary) in modes
      assert (if e, do: :exclusive) in modes
    end

    test "can override access and keep others default" do
      %{sync: s, worm: w} = V1.default_options()

      assert %V1{modes: modes, sync: ^s, worm: ^w} =
               V1.init(%{access: :append})

      assert :append in modes
    end

    test "invalid option value should fail" do
      assert {:error, {:invalid_access_option, :nope}} ==
               V1.init(%{access: :nope})
    end

    test "unknown option should fail" do
      assert {:error, {:unknown_option, :bogus}} ==
               V1.init(%{bogus: true})
    end
  end

  describe "normalize_options/1" do
    test "valid values as strings convert to atoms" do
      assert %{access: :append} == V1.normalize_options(%{access: "append"})
      assert %{binary: false} == V1.normalize_options(%{binary: "false"})
    end

    test "invalid values should error" do
      assert {:error, {:invalid_binary_option, "sometimes"}} ==
               V1.normalize_options(%{binary: "sometimes"})
      assert {:error, {:invalid_exclusive_option, 1}} ==
               V1.normalize_options(%{exclusive: 1})
    end

    test "unknown keys should be removed" do
      assert %{sync: true} ==
               V1.normalize_options(%{sync: "true", extra: :ignored})
    end
  end

  describe "file operations" do
    setup %{tmp_dir: path} do
      file = Path.join(System.tmp_dir!(), "file_writer_standard_v1_test_#{System.unique_integer()}")
      on_exit(fn -> File.rm_rf(path) end)
      {:ok, path: file}
    end

    @tag :tmp_dir
    test "open/write/close writes content", %{path: path} do
      writer = V1.init(%{})
      assert {:ok, handle} = V1.open(writer, path)

      assert :ok == V1.write(writer, handle, "hello")
      assert :ok == V1.close(writer, handle)

      assert {:ok, "hello"} == File.read(path)
    end

    @tag :tmp_dir
    test "sync option fsyncs after write", %{path: path} do
      writer = V1.init(%{sync: true})
      assert {:ok, handle} = V1.open(writer, path)

      assert :ok == V1.write(writer, handle, "abc")
      assert :ok == V1.close(writer, handle)

      assert {:ok, "abc"} == File.read(path)
    end

    @tag :tmp_dir
    test "worm option makes file read-only on finalize", %{path: path} do
      writer = V1.init(%{worm: true})
      assert {:ok, handle} = V1.open(writer, path)

      :ok = V1.write(writer, handle, "locked")
      :ok = V1.close(writer, handle)

      assert :ok == V1.finalize(writer, path)

      # Should now be read-only
      {:ok, stat} = File.stat(path)
      assert (stat.mode &&& 0o777) == 0o444
    end

    @tag :tmp_dir
    test "finalize does nothing when worm=false", %{path: path} do
      writer = V1.init(%{worm: false})
      assert {:ok, handle} = V1.open(writer, path)

      :ok = V1.write(writer, handle, "free")
      :ok = V1.close(writer, handle)

      assert :ok == V1.finalize(writer, path)

      {:ok, stat} = File.stat(path)
      assert stat.mode != 0o444
    end
  end
end
