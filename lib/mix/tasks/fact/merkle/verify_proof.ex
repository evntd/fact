defmodule Mix.Tasks.Fact.Merkle.VerifyProof do
  use Mix.Task

  @shortdoc "Verifies an MMR inclusion proof from a JSON file"

  @moduledoc """
  Verifies an MMR inclusion proof from a JSON file.

  This task does **not** require access to the database. It reads a proof previously
  exported by `mix fact.merkle.create_proof --output proof.json`, recomputes the hash path
  from the leaf through the sibling hashes, and checks that the result matches one of
  the peaks. This allows an auditor to independently confirm that an event is part of
  the committed history.

  ## Usage

      mix fact.merkle.verify_proof --proof proof.json

  ## Options

    * `--proof` - (required) Path to the JSON proof file produced by `mix fact.merkle.create_proof -o`.
  """

  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    {parsed, _, _} =
      OptionParser.parse(args, strict: [proof: :string])

    proof_path = fetch_required!(parsed, :proof)

    unless File.exists?(proof_path) do
      Mix.raise("Proof file not found: #{proof_path}")
    end

    json = proof_path |> File.read!() |> Jason.decode!()

    proof = %{
      leaf_index: Map.fetch!(json, "leaf_index"),
      leaf_hash: decode_hex!(json, "leaf_hash"),
      sibling_hashes: Enum.map(Map.fetch!(json, "sibling_hashes"), &Base.decode16!(&1, case: :mixed)),
      peaks: Enum.map(Map.fetch!(json, "peaks"), &Base.decode16!(&1, case: :mixed))
    }

    algorithm =
      json
      |> Map.fetch!("hash_algorithm")
      |> String.to_existing_atom()

    Mix.shell().info("Verifying inclusion proof (leaf index #{proof.leaf_index})...")

    case Fact.MerkleMountainRange.verify_proof(proof, algorithm) do
      :ok ->
        Mix.shell().info("Proof is valid. The event is included in the committed history.")

      {:error, :proof_invalid} ->
        Mix.shell().error("Proof is INVALID. The computed hash does not match any peak.")
        System.halt(1)

      {:error, reason} ->
        Mix.raise("Verification failed: #{inspect(reason)}")
    end
  end

  defp decode_hex!(json, key) do
    json |> Map.fetch!(key) |> Base.decode16!(case: :mixed)
  end

  defp fetch_required!(opts, key) do
    case Keyword.get(opts, key) do
      nil -> Mix.raise("Missing required option: --#{key}")
      value -> value
    end
  end
end
