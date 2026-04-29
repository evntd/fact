defmodule Mix.Tasks.Fact.Merkle.Root do
  use Mix.Task

  @shortdoc "Prints the current MMR peak hashes for a database"

  @moduledoc """
  Prints the current MMR peak hashes for a database.

  The peak hashes together form the root commitment to the entire event history.
  These can be shared with auditors for independent verification.

  ## Usage

      mix fact.merkle.root -p <path>

  ## Options

    * `-p`, `--path` - (required) Path to the database directory.
  """

  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    {parsed, _, _} =
      OptionParser.parse(args, strict: [path: :string], aliases: [p: :path])

    path = fetch_required!(parsed, :path)

    {:ok, db} = Fact.open(path, :merkle)

    case Fact.MerkleMountainRange.peaks(db) do
      {:ok, []} ->
        Mix.shell().info("MMR is empty (no events committed).")

      {:ok, peak_hashes} ->
        Mix.shell().info("MMR peaks (#{length(peak_hashes)}):")

        Enum.with_index(peak_hashes, 1)
        |> Enum.each(fn {hash, i} ->
          Mix.shell().info("  #{i}. #{Base.encode16(hash, case: :lower)}")
        end)

      {:error, :not_enabled} ->
        Mix.raise("MMR is not enabled for this database. Is it configured with CAS mode?")

      {:error, reason} ->
        Mix.raise("Failed to read peaks: #{inspect(reason)}")
    end
  end

  defp fetch_required!(opts, key) do
    case Keyword.get(opts, key) do
      nil -> Mix.raise("Missing required option: --#{key}")
      value -> value
    end
  end
end
