defmodule Mix.Tasks.Fact.Merkle.CreateProof do
  use Mix.Task

  @shortdoc "Creates an inclusion proof for an event at a given ledger position"

  @moduledoc """
  Creates an inclusion proof for an event at a given ledger position.

  The proof can be used to verify that a specific event is part of the committed
  event history without requiring access to the full database.

  ## Usage

      mix fact.merkle.create_proof -p <path> --position <N>
      mix fact.merkle.create_proof -p <path> --position <N> --output proof.json

  ## Options

    * `-p`, `--path` - (required) Path to the database directory.
    * `--position` - (required) The store position of the event to prove.
    * `-o`, `--output` - Write the proof as JSON to the given file path.
      Without this flag the proof is printed in human-readable format.
  """

  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    {parsed, _, _} =
      OptionParser.parse(args,
        strict: [path: :string, position: :integer, output: :string],
        aliases: [p: :path, o: :output]
      )

    path = fetch_required!(parsed, :path)
    position = fetch_required!(parsed, :position)
    output = Keyword.get(parsed, :output)

    {:ok, db} = Fact.open(path, :merkle)

    case Fact.MerkleMountainRange.create_proof(db, position) do
      {:ok, proof} ->
        if output do
          write_json(proof, output, db)
        else
          print_proof(proof, position)
        end

      {:error, :position_out_of_range} ->
        Mix.raise("Position #{position} is out of range.")

      {:error, :not_enabled} ->
        Mix.raise("MMR is not enabled for this database. Is it configured with CAS mode?")

      {:error, reason} ->
        Mix.raise("Failed to create proof: #{inspect(reason)}")
    end
  end

  defp print_proof(proof, position) do
    Mix.shell().info("Inclusion proof for event at store position #{position}:")
    Mix.shell().info("  Leaf index: #{proof.leaf_index}")
    Mix.shell().info("  Leaf hash:  #{Base.encode16(proof.leaf_hash, case: :lower)}")

    Mix.shell().info("  Sibling hashes (#{length(proof.sibling_hashes)}):")

    Enum.with_index(proof.sibling_hashes, 1)
    |> Enum.each(fn {hash, i} ->
      Mix.shell().info("    #{i}. #{Base.encode16(hash, case: :lower)}")
    end)

    Mix.shell().info("  Peaks (#{length(proof.peaks)}):")

    Enum.with_index(proof.peaks, 1)
    |> Enum.each(fn {hash, i} ->
      Mix.shell().info("    #{i}. #{Base.encode16(hash, case: :lower)}")
    end)
  end

  defp write_json(proof, output, database_id) do
    {:ok, context} = Fact.Registry.get_context(database_id)
    %{state: %{algorithm: algorithm}} = context.record_file_name

    json =
      %{
        leaf_index: proof.leaf_index,
        leaf_hash: Base.encode16(proof.leaf_hash, case: :lower),
        sibling_hashes: Enum.map(proof.sibling_hashes, &Base.encode16(&1, case: :lower)),
        peaks: Enum.map(proof.peaks, &Base.encode16(&1, case: :lower)),
        hash_algorithm: algorithm
      }
      |> Jason.encode!(pretty: true)

    File.write!(output, json)
    Mix.shell().info("Proof written to #{output}")
  end

  defp fetch_required!(opts, key) do
    case Keyword.get(opts, key) do
      nil -> Mix.raise("Missing required option: --#{key}")
      value -> value
    end
  end
end
