defmodule Fact.RecordFile.Writer do
  use Fact.Seam.FileWriter.Adapter,
    context: :record_file_writer,
    fixed_options: %{
      {:standard, 1} => %{
        access: :write,
        binary: true,
        exclusive: true,
        raw: true,
        sync: true,
        worm: true
      }
    }
end
