defmodule Fact.IndexCheckpointFile.Writer do
  use Fact.Seam.FileWriter.Adapter,
    context: :index_checkpoint_file_writer,
    fixed_options: %{
      {:standard, 1} => %{
        access: :write,
        binary: true,
        exclusive: false,
        sync: true,
        worm: false
      }
    }
end
