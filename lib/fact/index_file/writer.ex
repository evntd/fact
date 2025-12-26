defmodule Fact.IndexFile.Writer do
  use Fact.Seam.FileWriter.Adapter,
    context: :index_file_writer,
    fixed_options: %{
      {:standard, 1} => %{
        access: :append,
        binary: true,
        exclusive: false,
        sync: false,
        worm: false
      }
    }
end
