defmodule Fact.RecordFile.Reader do
  use Fact.Seam.FileReader.Adapter,
    context: :record_file_reader,
    allowed_impls: [{:full, 1}]

  def read(%Context{} = context, path) do
    read(context, path, []) |> Enum.at(0)
  end
end
