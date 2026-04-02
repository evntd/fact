defmodule Fact.Bootstrapper do
  @moduledoc """
  Boots a Fact database from disk.

  The bootstrapper read the **genesis event** (see `Fact.Genesis.Event.DatabaseCreated.V1`) from 
  the specified path, builds a `Fact.Context`, and starts the database under a `Fact.DatabaseSupervisor`.

  On success, the database is started and the bootstrapping process stops normally.
  If a `caller` PID is provided in the options, it will receive:

    * `{:database_started, database_id}`

  This process is temporary and is intended to run during startup.
  """
  use GenServer

  require Logger

  @typedoc since: "0.3.0"
  @type option ::
          {:path, Path.t()}
          | {:caller, pid()}
          | {:opts, [Fact.DatabaseSupervisor.subsystem_option()]}

  @type options :: list(option)

  cond do
    Code.ensure_loaded?(Elixir.JSON) ->
      @decode_json &JSON.decode/1

    Code.ensure_loaded?(Jason) ->
      @decode_json &Jason.decode/1

    true ->
      @decode_json fn _ -> {:error, :no_json_library_available} end
  end

  @spec child_spec(options()) :: Supervisor.child_spec()
  def child_spec(opts) do
    path = Keyword.fetch!(opts, :path)

    %{
      id: {__MODULE__, path},
      start: {__MODULE__, :start_link, [opts]},
      restart: :temporary
    }
  end

  @spec start_link(options()) :: GenServer.on_start()
  def start_link(opts) do
    with {:ok, path} <- Keyword.fetch(opts, :path) do
      arg = %{
        path: path,
        caller: Keyword.get(opts, :caller),
        opts: Keyword.get(opts, :opts, [])
      }

      GenServer.start_link(__MODULE__, arg, opts)
    else
      :error ->
        {:error, :missing_path}
    end
  end

  @impl true
  @doc false
  def init(args) do
    {:ok, args, {:continue, :bootstrap}}
  end

  @impl true
  @doc false
  def handle_continue(:bootstrap, %{path: path, caller: caller, opts: opts} = state) do
    with {:ok, context, encryption_runtime_opts} <- load_context(path, opts) do
      merged_opts = Keyword.merge(opts, encryption_runtime_opts)

      case Fact.Registry.get_context(context.database_id) do
        {:ok, _} ->
          maybe_send(caller, {:database_started, context.database_id})
          {:stop, :normal, state}

        {:error, _} ->
          case start_database(context, merged_opts) do
            {:ok, _pid} ->
              maybe_send(caller, {:database_started, context.database_id})
              {:stop, :normal, state}

            {:error, {:locked, lock_info}} ->
              maybe_send(caller, {:database_locked, lock_info})
              {:stop, :normal, state}

            {:error, reason} ->
              {:stop, reason, state}
          end
      end
    else
      {:error, reason} ->
        maybe_send(caller, {:database_error, reason})
        {:stop, :normal, state}
    end
  end

  defp start_database(context, opts) do
    case Fact.Lock.status(context) do
      {:ok, :unlocked} ->
        Supervisor.start_child(
          Fact.Supervisor,
          {Fact.DatabaseSupervisor, [context: context, opts: opts]}
        )

      {:ok, lock_info} ->
        {:error, {:locked, lock_info}}
    end
  end

  defp load_context_from_bootstrap_file(path, opts) do
    with {:ok, bootstrap} <- Fact.BootstrapFile.read(path),
         {:ok, dek, encryption_runtime_opts} <- resolve_encryption(bootstrap, opts) do
      bootstrap_context = %Fact.Context{
        event_schema: Fact.Event.Schema.from_config(bootstrap["event_schema"]),
        record_file_decoder:
          Fact.RecordFile.Decoder.from_config(bootstrap["record_file_decoder"]),
        record_file_reader:
          Fact.RecordFile.Reader.from_config(
            bootstrap["record_file_reader"] ||
              %{"family" => "full", "version" => 1, "options" => %{}}
          ),
        storage: Fact.Storage.from_config(bootstrap["storage"])
      }

      {_, event} = read_genesis_record(bootstrap_context, bootstrap["record_id"], dek)

      event_data = Map.get(event, Fact.Event.Schema.get(bootstrap_context).event_data)
      context = Fact.Context.from_genesis_event_data(event_data)

      {:ok, context, encryption_runtime_opts}
    end
  end

  defp resolve_encryption(bootstrap, opts) do
    case bootstrap["encryption"] do
      nil ->
        {:ok, nil, []}

      encryption_config ->
        with {:ok, kek} <- fetch_kek(opts),
             {:ok, wrapped_dek} <- get_wrapped_dek(encryption_config),
             {:ok, dek} <- unwrap_dek(wrapped_dek, kek) do
          {:ok, dek, [encryption: [wrapped_dek: wrapped_dek, kek: kek]]}
        end
    end
  end

  # When encrypted, read raw file with Full.V1 and decrypt before decoding.
  defp read_genesis_record(context, record_id, dek) when is_binary(dek) do
    {:ok, record_path} = {:ok, Fact.Storage.records_path(context, record_id)}

    {:ok, stream} =
      Fact.Seam.FileReader.Full.V1.read(%Fact.Seam.FileReader.Full.V1{}, record_path, [])

    encrypted_binary = Enum.at(stream, 0)
    {:ok, plaintext} = Fact.Seam.FileReader.Encrypted.V1.decrypt_binary(dek, encrypted_binary)
    {:ok, record} = Fact.RecordFile.Decoder.decode(context, plaintext)
    {record_id, record}
  end

  defp read_genesis_record(context, record_id, nil) do
    Fact.RecordFile.read(context, record_id)
  end

  defp fetch_kek(opts) do
    case Keyword.get(opts, :encryption_key) do
      value when is_binary(value) ->
        decode_encryption_key(value)

      nil ->
        encryption_opts = Keyword.get(opts, :encryption, [])

        case Keyword.get(encryption_opts, :kek_provider) do
          nil ->
            {:error, :encryption_key_required}

          provider ->
            provider.fetch_kek(encryption_opts)
        end
    end
  end

  defp decode_encryption_key(value) do
    case Base.decode64(value) do
      {:ok, key} when byte_size(key) in [16, 24, 32] ->
        {:ok, key}

      {:ok, key} ->
        {:error, {:invalid_encryption_key_size, byte_size(key)}}

      :error ->
        {:error, {:invalid_encryption_key, "must be valid base64"}}
    end
  end

  defp unwrap_dek(wrapped_dek, kek) do
    case Fact.KeyRing.unwrap_dek(wrapped_dek, kek) do
      {:ok, dek} -> {:ok, dek}
      {:error, :dek_unwrap_failed} -> {:error, :invalid_encryption_key}
      error -> error
    end
  end

  defp get_wrapped_dek(encryption_config) do
    {:ok, Base.decode64!(encryption_config["wrapped_dek_primary"])}
  end

  defp load_context(path, opts) do
    case load_context_from_bootstrap_file(path, opts) do
      {:error, :bootstraps_not_found} ->
        case load_context_v1(path) do
          {:ok, context} -> {:ok, context, []}
          error -> error
        end

      {:ok, _context, _encryption_opts} = result ->
        result

      {:error, _reason} = error ->
        error
    end
  end

  @doc deprecated: "use load_context_from_bootstrap_file/1"
  defp load_context_v1(path) do
    ledger_file = Path.join(path, ".ledger")

    if File.exists?(ledger_file) do
      genesis_id =
        File.stream!(ledger_file)
        |> Enum.take(1)
        |> List.first()
        |> String.trim()

      genesis_path = Path.join([path, "events", genesis_id])
      {:ok, genesis_json} = File.read(genesis_path)
      {:ok, genesis_record} = @decode_json.(genesis_json)
      {:ok, Fact.Context.from_record(genesis_record)}
    else
      {:error, :database_not_found}
    end
  end

  defp maybe_send(caller, message) do
    if is_pid(caller), do: send(caller, message)
  end
end
