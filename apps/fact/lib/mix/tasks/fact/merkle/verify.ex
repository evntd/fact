defmodule Mix.Tasks.Fact.Merkle.Verify do
  use Mix.Task

  @shortdoc "Verifies the integrity of a database's Merkle Mountain Range"

  @moduledoc """
  Verifies the integrity of a database's Merkle Mountain Range.

  Rebuilds the MMR from all stored events and compares it against the on-disk MMR file.
  Reports any discrepancies, pinpointing which event positions have been tampered with.

  ## Usage

      mix fact.merkle.verify -p <path>

  ## Options

    * `-p`, `--path` - (required) Path to the database directory.
  """

  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    {parsed, _, _} =
      OptionParser.parse(args, strict: [path: :string], aliases: [p: :path])

    path = fetch_required!(parsed, :path)

    Mix.shell().info("Verifying Merkle Mountain Range at #{path}...")

    {:ok, db} = Fact.open(path, :merkle)
    result = Fact.MerkleMountainRange.verify(db)

    case result do
      :ok ->
        Mix.shell().info("Verification passed. No tampering detected.")

      {:error, :tampered, positions} ->
        Mix.shell().error("Tampering detected at #{length(positions)} position(s):")

        Enum.each(positions, fn pos ->
          Mix.shell().error("  - store position #{pos}")
        end)

      {:error, :not_enabled} ->
        Mix.raise("MMR is not enabled for this database. Is it configured with CAS mode?")

      {:error, reason} ->
        Mix.raise("Verification failed: #{inspect(reason)}")
    end
  end

  defp fetch_required!(opts, key) do
    case Keyword.get(opts, key) do
      nil -> Mix.raise("Missing required option: --#{key}")
      value -> value
    end
  end
end
