defmodule Mix.Tasks.Fact.Backup do
  use Mix.Task

  @shortdoc "Backs up a Fact database directory into a zip file"

  @moduledoc """
  Backs up the contents of a Fact database.

  ## Usage

      mix fact.backup --path path/to/db --output backup.zip
      mix fact.backup --path path/to/db --output some_dir
      mix fact.backup --path path/to/db --output some_dir --include-indices

  If the output path is a directory, the ZIP file name is derived from the
  last segment of the input path plus a timestamp.
  """

  @impl true
  def run(args) do
    {parsed, _argv, _invalid} =
      OptionParser.parse(args,
        strict: [
          path: :string,
          output: :string,
          include_indices: :boolean
        ]
      )

    path   = fetch_required!(parsed, :path)
    output = fetch_required!(parsed, :output)
    include_indices = Keyword.get(parsed, :include_indices, false)

    unless File.dir?(path) do
      Mix.raise("Path does not exist or is not a directory: #{path}")
    end

    output =
      cond do
        File.dir?(output) ->
          timestamp = timestamp()
          base = Path.basename(Path.expand(path))
          Path.join(output, "#{base}_#{timestamp}.zip")

        true ->
          output
      end

    files_to_add =
      collect_files(path, include_indices)
      |> Enum.map(&relative_zip_tuple(path, &1))

    Mix.shell().info("Creating backup zip: #{output}")

    case :zip.create(String.to_charlist(output), files_to_add, [:memory]) do
      {:ok, {_zip_name, zip_binary}} ->
        File.write!(output, zip_binary)
        Mix.shell().info("Backup created successfully at #{output}")

      {:error, reason} ->
        Mix.raise("Failed to create zip: #{inspect(reason)}")
    end
  end

  # --------- Helpers ---------

  defp fetch_required!(opts, key) do
    case Keyword.get(opts, key) do
      nil -> Mix.raise("Missing required option: --#{key}")
      value -> value
    end
  end

  defp collect_files(base, include_indices) do
    required_files =
      [".bootstrap", ".gitignore", ".ledger"]
      |> Enum.map(&Path.join(base, &1))
      |> Enum.filter(&File.exists?/1)

    events = Path.join(base, "events") |> collect_tree()

    indices =
      if include_indices do
        Path.join(base, "indices") |> collect_tree()
      else
        []
      end

    required_files ++ events ++ indices
  end

  defp collect_tree(path) do
    if File.dir?(path) do
      Path.wildcard(Path.join(path, "**/*"))
      |> Enum.filter(&File.regular?/1)
    else
      []
    end
  end

  defp relative_zip_tuple(base, full_path) do
    relative = Path.relative_to(full_path, base)
    {String.to_charlist(relative), File.read!(full_path)}
  end

  defp timestamp do
    {{y, m, d}, {hh, mm, ss}} = :calendar.local_time()

    [
      y |> pad(4),
      m |> pad(2),
      d |> pad(2),
      "_",
      hh |> pad(2),
      mm |> pad(2),
      ss |> pad(2)
    ]
    |> IO.iodata_to_binary()
  end

  defp pad(int, size) do
    int
    |> Integer.to_string()
    |> String.pad_leading(size, "0")
  end
end
