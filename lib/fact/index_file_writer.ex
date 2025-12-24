defmodule Fact.IndexFileWriter do
  use Fact.Seam.Adapter,
    registry: Fact.Seam.FileWriter.Registry

  alias Fact.Context

  def open(%Context{index_file_writer: instance}, path) do
    __seam_call__(instance, :open, [path])
  end

  def write(%Context{index_file_writer: instance}, handle, content) do
    __seam_call__(instance, :write, [handle, content])
  end

  def close(%Context{index_file_writer: instance}, handle) do
    __seam_call__(instance, :close, [handle])
  end

  def finalize(%Context{index_file_writer: instance}, handle) do
    __seam_call__(instance, :finalize, [handle])
  end
end
