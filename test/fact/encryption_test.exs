defmodule Fact.EncryptionTest do
  @moduledoc false

  use ExUnit.Case

  @moduletag :capture_log

  describe "KEKProvider.Explicit" do
    alias Fact.Encryption.KEKProvider.Explicit

    test "returns KEK when valid 32-byte key provided" do
      kek = :crypto.strong_rand_bytes(32)
      assert {:ok, ^kek} = Explicit.fetch_kek(kek: kek)
    end

    test "accepts 16-byte key" do
      kek = :crypto.strong_rand_bytes(16)
      assert {:ok, ^kek} = Explicit.fetch_kek(kek: kek)
    end

    test "accepts 24-byte key" do
      kek = :crypto.strong_rand_bytes(24)
      assert {:ok, ^kek} = Explicit.fetch_kek(kek: kek)
    end

    test "returns error for invalid key size" do
      assert {:error, {:invalid_kek_size, 10}} =
               Explicit.fetch_kek(kek: :crypto.strong_rand_bytes(10))
    end

    test "returns error when kek not provided" do
      assert {:error, :kek_not_provided} = Explicit.fetch_kek([])
    end

    test "returns error when kek is not binary" do
      assert {:error, :kek_must_be_binary} = Explicit.fetch_kek(kek: 12345)
    end
  end

  describe "KeyRing" do
    test "wrap and unwrap DEK round-trips" do
      dek = Fact.KeyRing.generate_dek()
      kek = :crypto.strong_rand_bytes(32)

      wrapped = Fact.KeyRing.wrap_dek(dek, kek)
      assert {:ok, ^dek} = Fact.KeyRing.unwrap_dek(wrapped, kek)
    end

    test "unwrap fails with wrong KEK" do
      dek = Fact.KeyRing.generate_dek()
      kek = :crypto.strong_rand_bytes(32)
      wrong_kek = :crypto.strong_rand_bytes(32)

      wrapped = Fact.KeyRing.wrap_dek(dek, kek)
      assert {:error, :dek_unwrap_failed} = Fact.KeyRing.unwrap_dek(wrapped, wrong_kek)
    end

    test "unwrap fails with invalid wrapped DEK" do
      kek = :crypto.strong_rand_bytes(32)
      assert {:error, :invalid_wrapped_dek} = Fact.KeyRing.unwrap_dek(<<1, 2, 3>>, kek)
    end

    test "generate_dek returns 32 bytes" do
      dek = Fact.KeyRing.generate_dek()
      assert byte_size(dek) == 32
    end
  end

  describe "Encrypted FileWriter and FileReader round-trip" do
    setup do
      dir = Path.join("tmp", "encryption_rw_test_#{:rand.uniform(1_000_000)}")
      File.mkdir_p!(dir)
      on_exit(fn -> File.rm_rf(dir) end)

      {:ok, dir: dir}
    end

    test "encrypts and decrypts a value", %{dir: _dir} do
      dek = Fact.KeyRing.generate_dek()
      plaintext = ~s({"event_type":"turtle_hatched","event_data":{"name":"Shelldon"}})

      nonce = :crypto.strong_rand_bytes(12)

      {ciphertext, auth_tag} =
        :crypto.crypto_one_time_aead(:aes_256_gcm, dek, nonce, plaintext, "", true)

      encrypted = <<nonce::binary-12, auth_tag::binary-16, ciphertext::binary>>

      {:ok, decrypted} = Fact.Seam.FileReader.Encrypted.V1.decrypt_binary(dek, encrypted)
      assert decrypted == plaintext
    end

    test "decrypt_binary fails with wrong key", %{dir: _dir} do
      dek = Fact.KeyRing.generate_dek()
      wrong_dek = Fact.KeyRing.generate_dek()
      plaintext = "secret data"

      nonce = :crypto.strong_rand_bytes(12)

      {ciphertext, auth_tag} =
        :crypto.crypto_one_time_aead(:aes_256_gcm, dek, nonce, plaintext, "", true)

      encrypted = <<nonce::binary-12, auth_tag::binary-16, ciphertext::binary>>

      assert {:error, :decryption_failed} =
               Fact.Seam.FileReader.Encrypted.V1.decrypt_binary(wrong_dek, encrypted)
    end

    test "decrypt_binary fails with truncated file" do
      dek = Fact.KeyRing.generate_dek()

      assert {:error, :invalid_encrypted_file} =
               Fact.Seam.FileReader.Encrypted.V1.decrypt_binary(dek, <<1, 2, 3>>)
    end
  end

  describe "end-to-end encrypted database" do
    setup do
      path =
        :uuid.get_v4()
        |> :uuid.uuid_to_string(:nodash)
        |> to_string()
        |> then(fn uuid -> "e2e_enc_" <> uuid end)
        |> String.downcase()
        |> String.split_at(63)
        |> then(fn {name, _} -> Path.join("tmp", name) end)

      # Create encrypted database — keys are auto-generated
      args = [
        path: path,
        record_file_writer: "encrypted@1",
        record_file_writer_options: "cipher=aes_gcm",
        record_file_reader: "encrypted@1",
        record_file_reader_options: "cipher=aes_gcm"
      ]

      command = %Fact.Genesis.Command.CreateDatabase.V1{args: args}

      {:ok, [genesis_event], encryption_meta} =
        Fact.Genesis.Decider.decide(Fact.Genesis.Decider.initial_state(), command)

      Fact.Genesis.TheCreator.let_there_be_light(genesis_event, encryption_meta)

      on_exit(fn -> TestHelper.rm_rf(path) end)

      {:ok, path: path, encryption_meta: encryption_meta}
    end

    test "keys are auto-generated when not provided", %{encryption_meta: meta} do
      assert byte_size(meta.kek) == 32
      assert byte_size(meta.recovery_kek) == 32
      assert byte_size(meta.dek) == 32
      assert meta.kek != meta.recovery_kek
    end

    test "genesis record file is not plaintext on disk", %{path: path} do
      record_file =
        Path.join(path, "events/**/*")
        |> Path.wildcard()
        |> Enum.reject(&File.dir?/1)
        |> hd()

      {:ok, bytes} = File.read(record_file)

      refute String.starts_with?(bytes, "{")
      assert byte_size(bytes) > 28
    end

    test "bootstrap file contains encryption metadata", %{path: path} do
      {:ok, bootstrap} = Fact.BootstrapFile.read(path)

      assert bootstrap["encryption"]
      assert bootstrap["encryption"]["wrapped_dek_primary"]
      assert bootstrap["encryption"]["wrapped_dek_recovery"]
      assert bootstrap["encryption"]["family"] == "aes_gcm"
    end

    test "open and read with encryption_key", %{path: path, encryption_meta: meta} do
      {:ok, db} = Fact.open(path, encryption_key: Base.encode64(meta.kek))

      events = Fact.read(db, :all)
      assert length(events) == 1
      assert hd(events)["event_type"] == "Elixir.Fact.Genesis.Event.DatabaseCreated.V1"
    end

    test "append and read encrypted events", %{path: path, encryption_meta: meta} do
      {:ok, db} = Fact.open(path, encryption_key: Base.encode64(meta.kek))

      event = %{type: "turtle_hatched", data: %{name: "Shelldon"}}
      {:ok, position} = Fact.append(db, event)

      TestHelper.subscribe_and_wait(db, position)

      [record] = Fact.read(db, :all, position: position - 1, count: 1)
      assert record["event_type"] == "turtle_hatched"
      assert record["event_data"]["name"] == "Shelldon"
    end

    test "wrong encryption key returns clear error", %{path: path} do
      wrong_key = :crypto.strong_rand_bytes(32) |> Base.encode64()
      assert {:error, :invalid_encryption_key} = Fact.open(path, encryption_key: wrong_key)
    end

    test "missing encryption key returns clear error", %{path: path} do
      assert {:error, :encryption_key_required} = Fact.open(path)
    end

    test "mix fact.recover rotates keys and re-encrypts records", %{
      path: path,
      encryption_meta: meta
    } do
      # Open, append an event, then close the database
      {:ok, db} = Fact.open(path, encryption_key: Base.encode64(meta.kek))
      {:ok, position} = Fact.append(db, %{type: "turtle_hatched", data: %{name: "Shelldon"}})
      TestHelper.subscribe_and_wait(db, position)
      # subscribe_and_wait links us to PubSub; trap exits during close
      Process.flag(:trap_exit, true)
      :ok = Fact.close(db)
      Process.flag(:trap_exit, false)

      # Run recovery with the recovery key
      Mix.Tasks.Fact.Recover.run([
        "--path",
        path,
        "--recovery-key",
        Base.encode64(meta.recovery_kek)
      ])

      # Old key should no longer work — bootstrap has new wrapped DEKs
      {:ok, bootstrap} = Fact.BootstrapFile.read(path)
      old_wrapped = Base.decode64!(bootstrap["encryption"]["wrapped_dek_primary"])
      assert {:error, :dek_unwrap_failed} = Fact.KeyRing.unwrap_dek(old_wrapped, meta.kek)
    end

    test "--encrypted flag via mix task creates encrypted database" do
      path =
        :uuid.get_v4()
        |> :uuid.uuid_to_string(:nodash)
        |> to_string()
        |> then(fn uuid -> "e2e_enc_flag_" <> uuid end)
        |> String.downcase()
        |> String.split_at(63)
        |> then(fn {name, _} -> Path.join("tmp", name) end)

      Mix.Tasks.Fact.Create.run(["--path", path, "--encrypted"])

      {:ok, bootstrap} = Fact.BootstrapFile.read(path)
      assert bootstrap["encryption"]
      assert bootstrap["record_file_writer"]["family"] == "encrypted"

      TestHelper.rm_rf(path)
    end

    test "user-provided keys are used when specified" do
      path =
        :uuid.get_v4()
        |> :uuid.uuid_to_string(:nodash)
        |> to_string()
        |> then(fn uuid -> "e2e_enc_custom_" <> uuid end)
        |> String.downcase()
        |> String.split_at(63)
        |> then(fn {name, _} -> Path.join("tmp", name) end)

      my_key = :crypto.strong_rand_bytes(32)
      my_recovery = :crypto.strong_rand_bytes(32)

      args = [
        path: path,
        record_file_writer: "encrypted@1",
        record_file_writer_options: "cipher=aes_gcm",
        record_file_reader: "encrypted@1",
        record_file_reader_options: "cipher=aes_gcm",
        key: Base.encode64(my_key),
        recovery_key: Base.encode64(my_recovery)
      ]

      command = %Fact.Genesis.Command.CreateDatabase.V1{args: args}

      {:ok, [genesis_event], encryption_meta} =
        Fact.Genesis.Decider.decide(Fact.Genesis.Decider.initial_state(), command)

      assert encryption_meta.kek == my_key
      assert encryption_meta.recovery_kek == my_recovery

      Fact.Genesis.TheCreator.let_there_be_light(genesis_event, encryption_meta)

      {:ok, db} = Fact.open(path, encryption_key: Base.encode64(my_key))
      events = Fact.read(db, :all)
      assert length(events) == 1

      TestHelper.rm_rf(path)
    end
  end
end
