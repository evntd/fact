defmodule Fact.LedgerFile.Writer do
  use Fact.Seam.FileWriter.Adapter,
    context: :ledger_file_writer,
    fixed_options: %{
      {:standard, 1} => %{
        access: :append,
        binary: true,
        exclusive: false,
        raw: true,
        sync: true,
        worm: false
      }
    }
end
