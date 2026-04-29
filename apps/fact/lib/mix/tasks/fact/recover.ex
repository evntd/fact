defmodule Mix.Tasks.Fact.Recover do
  @moduledoc """
  Recovers an encrypted database using the recovery key.

  This task performs a full key rotation: it decrypts all record files with the
  old Data Encryption Key (DEK), generates a new DEK along with new primary and
  recovery keys, re-encrypts every record, and updates the `.bootstrap` file.

  The database **must not be running** during recovery.

  ## Usage

      mix fact.recover --path data/my_db --recovery-key <base64_key>

  ## Options

    * `--path` / `-p` — (required) Path to the database directory.
    * `--recovery-key` — (required) Base64-encoded recovery key.
  """

  use Mix.Task

  @shortdoc "Recovers an encrypted database with a recovery key"

  @switches [
    path: :string,
    recovery_key: :string
  ]

  @aliases [p: :path]

  @impl true
  def run(args) do
    {parsed, _argv, _invalid} = OptionParser.parse(args, strict: @switches, aliases: @aliases)

    path = fetch_required!(parsed, :path)
    recovery_key_b64 = fetch_required!(parsed, :recovery_key)

    unless File.dir?(path) do
      Mix.raise("Path does not exist or is not a directory: #{path}")
    end

    with {:ok, recovery_key} <- decode_key(recovery_key_b64),
         {:ok, bootstrap} <- Fact.BootstrapFile.read(path),
         {:ok, encryption_config} <- get_encryption_config(bootstrap),
         {:ok, old_dek} <- unwrap_with_recovery(encryption_config, recovery_key),
         {:ok, context} <- load_context(bootstrap, old_dek) do
      # Collect all record IDs from the ledger
      record_ids = Fact.LedgerFile.read(context) |> Enum.to_list()
      total = length(record_ids)

      Mix.shell().info("Recovering #{total} record(s)...\n")

      # Generate new keys
      new_dek = Fact.KeyRing.generate_dek()
      new_key = :crypto.strong_rand_bytes(32)
      new_recovery_key = :crypto.strong_rand_bytes(32)

      # Re-encrypt each record
      record_ids
      |> Enum.with_index(1)
      |> Enum.each(fn {record_id, index} ->
        record_path = Fact.Storage.records_path(context, record_id)

        # Make writable (records are WORM)
        File.chmod!(record_path, 0o644)

        # Decrypt with old DEK
        {:ok, encrypted} = File.read(record_path)
        {:ok, plaintext} = Fact.Seam.FileReader.Encrypted.V1.decrypt_binary(old_dek, encrypted)

        # Re-encrypt with new DEK
        nonce = :crypto.strong_rand_bytes(12)

        {ciphertext, auth_tag} =
          :crypto.crypto_one_time_aead(:aes_256_gcm, new_dek, nonce, plaintext, "", true)

        new_encrypted = <<nonce::binary-12, auth_tag::binary-16, ciphertext::binary>>

        File.write!(record_path, new_encrypted)
        File.chmod!(record_path, 0o444)

        percent = div(index * 100, total)
        Mix.shell().info("\r  [#{percent}%] #{index}/#{total}")
      end)

      # Update bootstrap with new wrapped DEKs
      new_wrapped_primary = Fact.KeyRing.wrap_dek(new_dek, new_key)
      new_wrapped_recovery = Fact.KeyRing.wrap_dek(new_dek, new_recovery_key)

      updated_bootstrap = %{
        bootstrap
        | "encryption" => %{
            bootstrap["encryption"]
            | "wrapped_dek_primary" => Base.encode64(new_wrapped_primary),
              "wrapped_dek_recovery" => Base.encode64(new_wrapped_recovery)
          }
      }

      write_bootstrap(path, updated_bootstrap)

      Mix.shell().info("""

      ================================================================
       Recovery complete. #{total} record(s) re-encrypted.
      ================================================================
       🔐 NEW ENCRYPTION KEYS — SAVE THESE NOW
      ================================================================

           KEY: #{Base.encode64(new_key)}
      RECOVERY: #{Base.encode64(new_recovery_key)}

      ================================================================

       The old keys are no longer valid.
       Store these keys securely — they will NOT be shown again.
      ================================================================
      """)
    else
      {:error, reason} ->
        Mix.raise("Recovery failed: #{inspect(reason)}")
    end
  end

  defp fetch_required!(opts, key) do
    case Keyword.get(opts, key) do
      nil ->
        Mix.raise("Missing required option: --#{key |> to_string() |> String.replace("_", "-")}")

      value ->
        value
    end
  end

  defp decode_key(b64) do
    case Base.decode64(b64) do
      {:ok, key} when byte_size(key) in [16, 24, 32] -> {:ok, key}
      {:ok, key} -> {:error, {:invalid_key_size, byte_size(key)}}
      :error -> {:error, :invalid_base64}
    end
  end

  defp get_encryption_config(%{"encryption" => config}) when is_map(config), do: {:ok, config}
  defp get_encryption_config(_), do: {:error, :database_not_encrypted}

  defp unwrap_with_recovery(encryption_config, recovery_key) do
    wrapped = Base.decode64!(encryption_config["wrapped_dek_recovery"])
    Fact.KeyRing.unwrap_dek(wrapped, recovery_key)
  end

  defp load_context(bootstrap, dek) do
    bootstrap_context = %Fact.Context{
      event_schema: Fact.Event.Schema.from_config(bootstrap["event_schema"]),
      record_file_decoder: Fact.RecordFile.Decoder.from_config(bootstrap["record_file_decoder"]),
      record_file_reader:
        Fact.RecordFile.Reader.from_config(
          bootstrap["record_file_reader"] ||
            %{"family" => "full", "version" => 1, "options" => %{}}
        ),
      storage: Fact.Storage.from_config(bootstrap["storage"])
    }

    # Read the genesis record to build the full context
    record_id = bootstrap["record_id"]
    {:ok, record_path} = {:ok, Fact.Storage.records_path(bootstrap_context, record_id)}

    {:ok, stream} =
      Fact.Seam.FileReader.Full.V1.read(%Fact.Seam.FileReader.Full.V1{}, record_path, [])

    encrypted_binary = Enum.at(stream, 0)
    {:ok, plaintext} = Fact.Seam.FileReader.Encrypted.V1.decrypt_binary(dek, encrypted_binary)
    {:ok, event} = Fact.RecordFile.Decoder.decode(bootstrap_context, plaintext)

    event_data = Map.get(event, Fact.Event.Schema.get(bootstrap_context).event_data)
    {:ok, Fact.Context.from_genesis_event_data(event_data)}
  end

  defp write_bootstrap(path, bootstrap_data) do
    bootstrap_context = %Fact.BootstrapFile.Context{
      encoder: Fact.BootstrapFile.Encoder.from_config(%{family: :json, version: 1, options: %{}}),
      name: Fact.BootstrapFile.Name.from_config(%{family: :fixed, version: 1, options: %{}}),
      writer:
        Fact.BootstrapFile.Writer.from_config(%{family: :standard, version: 1, options: %{}})
    }

    bootstrap_path = Path.join(path, Fact.BootstrapFile.Name.get(bootstrap_context))

    # Bootstrap is WORM, make writable before overwriting
    File.chmod!(bootstrap_path, 0o644)

    {:ok, encoded} = Fact.BootstrapFile.Encoder.encode(bootstrap_context, bootstrap_data)
    Fact.BootstrapFile.Writer.write(bootstrap_context, bootstrap_path, encoded)

    File.chmod!(bootstrap_path, 0o444)
  end
end
