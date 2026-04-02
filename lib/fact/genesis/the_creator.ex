defmodule Fact.Genesis.TheCreator do
  @moduledoc """
  The divine module that brings a Fact database into existence.  

  `Fact.Genesis.TheCreator` is responsible for taking a `DatabaseCreated.V1` 
  event and actually creating the on-disk database via `let_there_be_light/1`.

  Responsibilities:
    * Initialize the storage paths for records and indices
    * Create necessary directories and a `.gitignore` file
    * Write the genesis event to the record file
    * Append the genesis event to the ledger file
    * Generate event IDs and populate the event schema
  """

  alias Fact.Genesis.Event.DatabaseCreated
  alias Fact.Event
  alias Fact.Storage

  @doc """
  Creates a Fact database from the `Fact.Genesis.Event.DatabaseCreated.V1` event.

  It initializes storage, and appends the event as the first record of every database.

  When `encryption_meta` is provided, the genesis record is encrypted manually
  (since the KeyRing process is not yet running) and the bootstrap file includes
  the wrapped DEK for later decryption.
  """
  @doc since: "0.3.1"
  @spec let_there_be_light(%DatabaseCreated.V1{}, map() | nil) :: :ok
  def let_there_be_light(%DatabaseCreated.V1{} = event, encryption_meta \\ nil) do
    with context <- DatabaseCreated.V1.to_context(event),
         {:ok, path} <- Storage.initialize_storage(context) do
      schema = Event.Schema.get(context)

      genesis =
        %{
          schema.event_type => to_string(event.__struct__),
          schema.event_id => Event.Id.generate(context),
          schema.event_data => Map.from_struct(event),
          schema.event_metadata => %{},
          schema.event_store_position => 1,
          schema.event_store_timestamp => DateTime.utc_now() |> DateTime.to_unix(:microsecond),
          schema.event_tags => ["__fact__:#{event.database_id}"]
        }

      {:ok, record_id} = write_genesis_record(context, genesis, encryption_meta)
      {:ok, ^record_id} = Fact.LedgerFile.write(context, record_id)

      bootstrap_opts = build_bootstrap_opts(encryption_meta)

      # writes the bare minimum into a special .bootstrap file
      # with just enough to read the genesis event and start the system.
      :ok = Fact.BootstrapFile.write(path, {record_id, event}, bootstrap_opts)

      :ok
    end
  end

  # When encrypted, we encode the genesis record normally, then encrypt and write
  # it manually. The KeyRing process doesn't exist yet during creation, so we
  # can't use the encrypted FileWriter seam.
  defp write_genesis_record(context, genesis, %{dek: dek} = _meta) do
    with {:ok, encoded} <- Fact.RecordFile.Encoder.encode(context, genesis),
         {:ok, record_id} <- Fact.RecordFile.Name.get(context, {genesis, encoded}),
         {:ok, record_path} <- {:ok, Storage.records_path(context, record_id)} do
      nonce = :crypto.strong_rand_bytes(12)

      {ciphertext, auth_tag} =
        :crypto.crypto_one_time_aead(:aes_256_gcm, dek, nonce, encoded, "", true)

      encrypted = <<nonce::binary-12, auth_tag::binary-16, ciphertext::binary>>

      :ok = File.write!(record_path, encrypted)
      File.chmod!(record_path, 0o444)

      {:ok, record_id}
    end
  end

  defp write_genesis_record(context, genesis, nil) do
    Fact.RecordFile.write(context, genesis)
  end

  defp build_bootstrap_opts(nil), do: []

  defp build_bootstrap_opts(%{wrapped_dek_primary: primary, wrapped_dek_recovery: recovery}) do
    [
      encryption: %{
        family: :aes_gcm,
        version: 1,
        wrapped_dek_primary: Base.encode64(primary),
        wrapped_dek_recovery: Base.encode64(recovery)
      }
    ]
  end
end
