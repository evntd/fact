defmodule Fact.Seam.FileReader.Encrypted.V1 do
  @moduledoc """
  Encrypted V1 implementation of `Fact.Seam.FileReader`.

  Reads a file written by `Fact.Seam.FileWriter.Encrypted.V1`, parsing the header
  to extract the nonce and authentication tag, then decrypting the ciphertext.

  The expected file format is:

      <<nonce::12-bytes, auth_tag::16-bytes, ciphertext::binary>>

  The Data Encryption Key (DEK) is retrieved from `Fact.KeyRing` at read time.

  ## Options

    * `:cipher` - The cipher algorithm. Currently only `:aes_gcm` is supported.
      Defaults to `:aes_gcm`.
  """
  @moduledoc since: "0.4.0"

  use Fact.Seam.FileReader,
    family: :encrypted,
    version: 1

  import Fact.Seam.Parsers, only: [parse_existing_atom: 1]

  @nonce_size 12
  @auth_tag_size 16
  @header_size @nonce_size + @auth_tag_size

  @enforce_keys [:cipher]
  defstruct [:cipher]

  @impl true
  def default_options(), do: %{cipher: :aes_gcm}

  @impl true
  def option_specs() do
    %{
      cipher: %{
        allowed: [:aes_gcm],
        parse: &parse_existing_atom/1,
        error: :invalid_cipher_option
      }
    }
  end

  @impl true
  def prepare_options(options), do: Map.take(options, [:cipher])

  @impl true
  def read(%__MODULE__{cipher: :aes_gcm}, path, options) do
    context = Keyword.get(options, :__context__)
    database_id = context.database_id

    with {:ok, dek} <- Fact.KeyRing.get_dek(database_id),
         {:ok, binary} <- File.read(path),
         {:ok, plaintext} <- decrypt_binary(dek, binary) do
      {:ok, Stream.map([plaintext], & &1)}
    end
  end

  @doc """
  Decrypts a binary that was written by `Fact.Seam.FileWriter.Encrypted.V1`.

  This is used by the bootstrapper to decrypt the genesis record before the
  `Fact.KeyRing` process is started.
  """
  @doc since: "0.4.0"
  @spec decrypt_binary(dek :: binary(), encrypted :: binary()) ::
          {:ok, binary()} | {:error, term()}
  def decrypt_binary(
        dek,
        <<nonce::binary-size(@nonce_size), auth_tag::binary-size(@auth_tag_size),
          ciphertext::binary>>
      ) do
    case :crypto.crypto_one_time_aead(:aes_256_gcm, dek, nonce, ciphertext, "", auth_tag, false) do
      plaintext when is_binary(plaintext) ->
        {:ok, plaintext}

      :error ->
        {:error, :decryption_failed}
    end
  end

  def decrypt_binary(_dek, binary) when byte_size(binary) < @header_size do
    {:error, :invalid_encrypted_file}
  end
end
