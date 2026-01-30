defmodule Mix.Tasks.Fact.Restore do
  use Mix.Task

  @shortdoc "Restores a Fact database from a backup zip file"

  @moduledoc """
  Restores a Fact database from a backup ZIP created by `mix fact.backup`.

  ## Usage

      mix fact.restore --path backup/test.zip --output tmp

  This will create a directory:

      tmp/test/

  And extract the backup contents into it.
  """

  @impl true
  def run(args) do
    {parsed, _argv, _invalid} =
      OptionParser.parse(args,
        strict: [
          path: :string,
          output: :string
        ]
      )

    path = fetch_required!(parsed, :path)
    output_dir = fetch_required!(parsed, :output)

    unless File.exists?(path) do
      Mix.raise("Backup file does not exist: #{path}")
    end

    unless String.ends_with?(path, ".zip") do
      Mix.raise("Backup file must be a .zip: #{path}")
    end

    # Determine restore directory name from zip basename
    base =
      path
      |> Path.basename(".zip")

    restore_path = Path.join(output_dir, base)

    Mix.shell().info("Restoring backup #{path} into #{restore_path}")

    File.mkdir_p!(restore_path)

    # Extract all files into the restore directory
    case :zip.extract(String.to_charlist(path), [:memory]) do
      {:ok, files} ->
        # files is a list of tuples: {'path/inside/zip', binary_contents}
        Enum.each(files, fn {zip_entry, contents} ->
          rel = List.to_string(zip_entry)
          dest = Path.join(restore_path, rel)

          # Ensure parent dirs
          dest |> Path.dirname() |> File.mkdir_p!()

          File.write!(dest, contents)
        end)

        Mix.shell().info("Restore completed successfully.")

      {:error, reason} ->
        Mix.raise("Failed to extract zip: #{inspect(reason)}")
    end
  end

  # --------- Helpers ---------

  defp fetch_required!(opts, key) do
    case Keyword.get(opts, key) do
      nil -> Mix.raise("Missing required option: --#{key}")
      value -> value
    end
  end
end
