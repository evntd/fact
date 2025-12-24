defmodule Fact.IndexFileWriter do
  alias Fact.Context
  alias Fact.Seam.Instance
  alias Fact.Seam.FileWriter.Registry

  def allowed_impls(), do: [{:standard, 1}]
  def default_impl(), do: {:standard, 1}
  def default_impl_options(), do: %{}
  def impl_registry(), do: Registry

  def open(%Context{index_file_writer: %Instance{module: mod, struct: s}}, path) do
    mod.open(s, path)
  end

  def write(%Context{index_file_writer: %Instance{module: mod, struct: s}}, handle, content) do
    mod.write(s, handle, content)
  end

  def close(%Context{index_file_writer: %Instance{module: mod, struct: s}}, handle) do
    mod.close(s, handle)
  end

  def finalize(%Context{index_file_writer: %Instance{module: mod, struct: s}}, handle) do
    mod.finalize(s, handle)
  end
end
