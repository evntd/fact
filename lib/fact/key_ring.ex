defmodule Fact.KeyRing do
  @moduledoc """
  Holds the Data Encryption Key (DEK) in memory for a database instance.

  The `Fact.KeyRing` is started as part of the `Fact.DatabaseSupervisor` when the database
  is configured with encryption. At startup, it unwraps the DEK using the configured
  `Fact.Encryption.KEKProvider` and holds it in memory for the lifetime of the database.

  The encrypted `Fact.Seam.FileWriter.Encrypted.V1` and `Fact.Seam.FileReader.Encrypted.V1`
  retrieve the DEK via `get_dek/1`.
  """
  @moduledoc since: "0.4.0"

  use GenServer

  @nonce_size 12
  @auth_tag_size 16

  @typedoc since: "0.4.0"
  @type option ::
          {:database_id, Fact.database_id()}
          | {:wrapped_dek, binary()}
          | {:kek, binary()}
          | {:name, GenServer.name()}

  @doc """
  Retrieves the DEK for the given database.
  """
  @doc since: "0.4.0"
  @spec get_dek(Fact.database_id()) :: {:ok, binary()} | {:error, term()}
  def get_dek(database_id) do
    GenServer.call(Fact.Registry.via(database_id, __MODULE__), :get_dek)
  end

  @doc false
  @spec child_spec([option()]) :: Supervisor.child_spec()
  def child_spec(opts) do
    database_id = Keyword.fetch!(opts, :database_id)

    %{
      id: {__MODULE__, database_id},
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  @doc false
  @spec start_link([option()]) :: GenServer.on_start()
  def start_link(opts) do
    {start_opts, init_opts} = Keyword.split(opts, [:name])
    GenServer.start_link(__MODULE__, init_opts, start_opts)
  end

  @impl true
  def init(opts) do
    wrapped_dek = Keyword.fetch!(opts, :wrapped_dek)
    kek = Keyword.fetch!(opts, :kek)

    # Prevent the DEK from appearing in crash dumps, :sys.get_state,
    # observer, and trace output.
    Process.flag(:sensitive, true)

    case unwrap_dek(wrapped_dek, kek) do
      {:ok, dek} ->
        {:ok, %{dek: dek}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_call(:get_dek, _from, %{dek: dek} = state) do
    {:reply, {:ok, dek}, state}
  end

  @doc """
  Wraps a DEK with a KEK using AES-256-GCM.

  Returns the wrapped DEK as `<<nonce::12-bytes, auth_tag::16-bytes, ciphertext::binary>>`.
  """
  @doc since: "0.4.0"
  @spec wrap_dek(dek :: binary(), kek :: binary()) :: binary()
  def wrap_dek(dek, kek) do
    nonce = :crypto.strong_rand_bytes(@nonce_size)
    {ciphertext, auth_tag} = :crypto.crypto_one_time_aead(:aes_256_gcm, kek, nonce, dek, "", true)
    <<nonce::binary-size(@nonce_size), auth_tag::binary-size(@auth_tag_size), ciphertext::binary>>
  end

  @doc """
  Unwraps a DEK using a KEK.

  Expects the wrapped DEK format: `<<nonce::12-bytes, auth_tag::16-bytes, ciphertext::binary>>`.
  """
  @doc since: "0.4.0"
  @spec unwrap_dek(wrapped_dek :: binary(), kek :: binary()) :: {:ok, binary()} | {:error, term()}
  def unwrap_dek(
        <<nonce::binary-size(@nonce_size), auth_tag::binary-size(@auth_tag_size),
          ciphertext::binary>>,
        kek
      ) do
    case :crypto.crypto_one_time_aead(:aes_256_gcm, kek, nonce, ciphertext, "", auth_tag, false) do
      dek when is_binary(dek) -> {:ok, dek}
      :error -> {:error, :dek_unwrap_failed}
    end
  end

  def unwrap_dek(_wrapped_dek, _kek), do: {:error, :invalid_wrapped_dek}

  @doc """
  Generates a random 256-bit DEK.
  """
  @doc since: "0.4.0"
  @spec generate_dek() :: binary()
  def generate_dek, do: :crypto.strong_rand_bytes(32)
end
