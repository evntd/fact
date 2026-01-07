defmodule Fact.Seam.FileName.Hash.V1 do
  @moduledoc """
  A file name implementation that generates a deterministic hashed name.

  This `Fact.Seam.FileName` implementation hashes the given value using a configurable
  algorithm (e.g., `:sha`, `:md5`, `:sha256`, etc.) and encodes the result in a configurable
  format (`:base16`, `:base32`, or `:base64url`).
  """
  use Fact.Seam.FileName,
    family: :hash,
    version: 1

  import Fact.Seam.Parsers, only: [parse_existing_atom: 1]

  @enforce_keys [:algorithm, :encoding]
  defstruct [:algorithm, :encoding]

  @impl true
  def default_options(), do: %{algorithm: :sha, encoding: :base16}

  @impl true
  def option_specs() do
    %{
      algorithm: %{
        allowed: [
          :sha,
          :md5,
          :sha256,
          :sha512,
          :sha3_256,
          :sha3_512,
          :blake2b,
          :blake2s
        ],
        parse: &parse_existing_atom/1,
        error: :invalid_algorithm_option
      },
      encoding: %{
        allowed: [
          :base16,
          :base32,
          :base64url
        ],
        parse: &parse_existing_atom/1,
        error: :invalid_encoding_option
      }
    }
  end

  @impl true
  def get(%__MODULE__{algorithm: algorithm, encoding: encoding}, index_value, _opts) do
    hash = :crypto.hash(algorithm, to_string(index_value))

    encoded =
      case encoding do
        :base64url ->
          Base.url_encode64(hash, padding: false)

        :base32 ->
          Base.encode32(hash, case: :lower, padding: false)

        :base16 ->
          Base.encode16(hash, case: :lower)
      end

    {:ok, encoded}
  end
end
