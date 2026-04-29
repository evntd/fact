defmodule Fact.Seam.FileWriter.Encrypted.V1 do
  @moduledoc """
  Encrypted V1 implementation of `Fact.Seam.FileWriter`.

  Encrypts the value before writing it to disk. Each file is written with a header
  containing a random nonce and authentication tag, followed by the ciphertext.

  The file format is:

      <<nonce::12-bytes, auth_tag::16-bytes, ciphertext::binary>>

  The Data Encryption Key (DEK) is retrieved from `Fact.KeyRing` at write time.

  ## Options

    * `:cipher` - The cipher algorithm. Currently only `:aes_gcm` is supported.
      Defaults to `:aes_gcm`.
    * `:access` - File access mode (`:write` or `:append`). Defaults to `:write`.
    * `:binary` - Whether to open in binary mode. Defaults to `true`.
    * `:exclusive` - Fail if the file already exists. Defaults to `true`.
    * `:raw` - Use raw file descriptors. Defaults to `false`.
    * `:sync` - Fsync after write. Defaults to `false`.
    * `:worm` - Mark file read-only after write. Defaults to `false`.
  """
  @moduledoc since: "0.4.0"

  use Fact.Seam.FileWriter,
    family: :encrypted,
    version: 1

  import Fact.Seam.Parsers, only: [parse_existing_atom: 1]

  @nonce_size 12
  @auth_tag_size 16

  @enforce_keys [:cipher, :modes, :sync, :worm]
  defstruct [:cipher, :modes, :sync, :worm]

  @impl true
  def default_options(),
    do: %{
      cipher: :aes_gcm,
      access: :write,
      binary: true,
      exclusive: true,
      raw: false,
      sync: false,
      worm: false
    }

  @impl true
  def option_specs() do
    %{
      cipher: %{
        allowed: [:aes_gcm],
        parse: &parse_existing_atom/1,
        error: :invalid_cipher_option
      },
      access: %{
        allowed: [:write, :append],
        parse: &parse_existing_atom/1,
        error: :invalid_access_option
      },
      binary: %{
        allowed: [true, false],
        parse: &parse_existing_atom/1,
        error: :invalid_binary_option
      },
      exclusive: %{
        allowed: [true, false],
        parse: &parse_existing_atom/1,
        error: :invalid_exclusive_option
      },
      raw: %{
        allowed: [true, false],
        parse: &parse_existing_atom/1,
        error: :invalid_raw_option
      },
      sync: %{
        allowed: [true, false],
        parse: &parse_existing_atom/1,
        error: :invalid_sync_option
      },
      worm: %{
        allowed: [true, false],
        parse: &parse_existing_atom/1,
        error: :invalid_worm_option
      }
    }
  end

  @impl true
  def prepare_options(options) do
    modes =
      [
        options.access,
        if(options.binary, do: :binary, else: nil),
        if(options.exclusive, do: :exclusive, else: nil),
        if(options.raw, do: :raw, else: nil)
      ]
      |> Enum.reject(&is_nil/1)

    options
    |> Map.take([:cipher, :sync, :worm])
    |> Map.put(:modes, modes)
  end

  @impl true
  def write(
        %__MODULE__{cipher: :aes_gcm, modes: modes, sync: sync, worm: worm},
        path,
        value,
        options
      ) do
    context = Keyword.get(options, :__context__)
    database_id = context.database_id

    with {:ok, dek} <- Fact.KeyRing.get_dek(database_id) do
      nonce = :crypto.strong_rand_bytes(@nonce_size)

      {ciphertext, auth_tag} =
        :crypto.crypto_one_time_aead(:aes_256_gcm, dek, nonce, value, "", true)

      encrypted_value =
        <<nonce::binary-size(@nonce_size), auth_tag::binary-size(@auth_tag_size),
          ciphertext::binary>>

      with {:ok, fd} <- File.open(path, modes),
           :ok <- IO.binwrite(fd, encrypted_value),
           :ok <- if(sync, do: :file.sync(fd), else: :ok),
           :ok <- File.close(fd),
           :ok <- if(worm, do: File.chmod(path, 0o444), else: :ok) do
        :ok
      end
    end
  end
end
