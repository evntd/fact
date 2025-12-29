defmodule Fact.Seam.FileName.ContentAddressable.V1 do
  use Fact.Seam.FileName,
    family: :content_addressable,
    version: 1

  import Fact.Seam.Parsers, only: [parse_existing_atom: 1]

  @enforce_keys [:algorithm, :encoding]
  defstruct [:algorithm, :encoding]

  @impl true
  def default_options(), do: %{algorithm: :sha256, encoding: :base64}

  @impl true
  def option_specs() do
    %{
      algorithm: %{
        allowed: [
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
  def get(%__MODULE__{algorithm: algorithm, encoding: encoding}, encoded_record, _options \\ []) do
    hash = :crypto.hash(algorithm, encoded_record)

    case encoding do
      :base64 ->
        Base.url_encode64(hash, padding: false)

      :base32 ->
        Base.encode32(hash, case: :lower, padding: false)

      :base16 ->
        Base.encode16(hash, case: :lower)
    end
  end
end
