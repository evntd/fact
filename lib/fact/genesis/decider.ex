defmodule Fact.Genesis.Decider do
  alias Fact.Genesis.Command.CreateDatabase
  alias Fact.Genesis.Event.DatabaseCreated

  def initial_state(), do: :initial_state

  def decide(:initial_state, %CreateDatabase.V1{args: args} = _command) do
    with {:ok, name} <- Keyword.fetch(args, :name),
         {:ok, path} <- Keyword.fetch(args, :path),
         :ok <- verify_path(path),
         {:ok, configuration} <- build_configuration(args) do
      info = %{
        database_id: generate_database_id(),
        database_name: name,
        elixir_version: elixir_version(),
        erts_version: erts_version(),
        fact_version: fact_version(),
        os_version: os_version(),
        otp_version: otp_version()
      }

      {:ok, [struct(DatabaseCreated.V1, Map.merge(info, configuration))]}
    end
  end

  def verify_path(path) do
    cond do
      File.exists?(path) ->
        cond do
          not File.dir?(path) ->
            {:error, :not_directory}

          File.ls(path) != {:ok, []} ->
            {:error, :not_empty_directory}

          true ->
            :ok
        end

      true ->
        :ok
    end
  end

  def evolve(_state, %DatabaseCreated.V1{} = _event), do: :created

  defp generate_database_id() do
    :uuid.get_v4() |> Base.encode32(padding: false)
  end

  defp os_version() do
    {_os_family, os_name} = :os.type()

    os_version =
      case :os.version() do
        {major, minor, release} ->
          "#{major}.#{minor}.#{release}"

        version_string ->
          version_string
      end

    "#{os_name} #{os_version}"
  end

  def otp_version(), do: :erlang.system_info(:otp_release) |> to_string()
  def erts_version(), do: :erlang.system_info(:version) |> to_string()
  def elixir_version(), do: System.version()
  def fact_version(), do: Fact.MixProject.project()[:version]

  @abstractions %{
    event_id: Fact.EventId,
    index_checkpoint_file_decoder: Fact.IndexCheckpointFile.Decoder,
    index_checkpoint_file_encoder: Fact.IndexCheckpointFile.Encoder,
    index_checkpoint_file_name: Fact.IndexCheckpointFile.Name,
    index_checkpoint_file_reader: Fact.IndexCheckpointFile.Reader,
    index_checkpoint_file_writer: Fact.IndexCheckpointFile.Writer,
    index_file_decoder: Fact.IndexFile.Decoder,
    index_file_encoder: Fact.IndexFile.Encoder,
    index_file_name: Fact.IndexFile.Name,
    index_file_reader: Fact.IndexFile.Reader,
    index_file_writer: Fact.IndexFile.Writer,
    ledger_file_decoder: Fact.LedgerFile.Decoder,
    ledger_file_encoder: Fact.LedgerFile.Encoder,
    ledger_file_name: Fact.LedgerFile.Name,
    ledger_file_reader: Fact.LedgerFile.Reader,
    ledger_file_writer: Fact.LedgerFile.Writer,
    lock_file_decoder: Fact.LockFile.Decoder,
    lock_file_encoder: Fact.LockFile.Encoder,
    lock_file_name: Fact.LockFile.Name,
    lock_file_reader: Fact.LockFile.Reader,
    lock_file_writer: Fact.LockFile.Writer,
    record_file_decoder: Fact.RecordFile.Decoder,
    record_file_encoder: Fact.RecordFile.Encoder,
    record_file_name: Fact.RecordFile.Name,
    record_file_reader: Fact.RecordFile.Reader,
    record_file_schema: Fact.RecordFile.Schema,
    record_file_writer: Fact.RecordFile.Writer,
    storage: Fact.Storage
  }

  defp build_configuration(args) do
    {:ok, config} =
      Enum.reduce_while(
        @abstractions,
        {:ok, %{}},
        fn {key, abstraction}, {:ok, acc} ->
          case resolve(args, key, abstraction) do
            {:ok, config} ->
              {:cont, {:ok, Map.put(acc, key, config)}}

            {:error, reason} ->
              {:halt, {:error, key, reason}}
          end
        end
      )

    handle_computed_configurations(args, config)
  end

  def resolve(args, key, abstraction) do
    with {:ok, parsed_impl_id} <- parse_impl_id(Keyword.get(args, key)),
         {:ok, parsed_impl_opts} <- parse_impl_options(Keyword.get(args, :"#{key}_options")),
         {:ok, impl_id = {family, version}} <- resolve_impl_id(parsed_impl_id, abstraction),
         {:ok, impl_opts} <- resolve_impl_options(parsed_impl_opts, abstraction, impl_id) do
      {:ok, %{family: family, version: version, options: impl_opts}}
    end
  end

  defp parse_impl_id(nil), do: {:ok, :default}

  defp parse_impl_id(value) do
    case String.split(value, "@") do
      [family, version] ->
        {:ok, {String.to_atom(family), String.to_integer(version)}}

      [family] ->
        {:ok, {String.to_atom(family), :default}}

      _ ->
        {:error, {:invalid_impl, value}}
    end
  end

  defp parse_impl_options(nil), do: {:ok, :default}

  defp parse_impl_options(value) do
    opts =
      value
      |> String.split(",")
      |> Enum.map(fn pair ->
        [k, v] = String.split(pair, "=", parts: 2)
        {String.to_atom(k), v}
      end)
      |> Map.new()

    {:ok, opts}
  end

  defp resolve_impl_id(value, abstraction) do
    case value do
      :default ->
        {:ok, abstraction.default_impl()}

      {family, :default} ->
        registry = abstraction.registry()
        version = registry.latest_version(family)
        {:ok, {family, version}}

      {family, version} ->
        {:ok, {family, version}}
    end
  end

  defp resolve_impl_options(options, abstraction, impl_id) do
    case options do
      :default ->
        {:ok, abstraction.default_options(impl_id)}

      _ ->
        abstraction.normalize_options(impl_id, options)
    end
  end

  defp handle_computed_configurations(
         args,
         %{
           ledger_file_reader: ledger_file_reader,
           index_file_reader: index_file_reader,
           storage: storage
         } = config
       ) do
    # This feels so gross, but I'm a bit stuck on some of the implicit coupling,
    # and don't want to introduce a ton of extra complexity, there is plenty already.

    with path <- Keyword.get(args, :path),
         {:ok, record_file_name_length} <- compute_record_file_name_length(config),
         {:ok, index_file_reader_padding} <- compute_index_file_reader_padding(config),
         {:ok, ledger_file_reader_padding} <- compute_ledger_file_reader_padding(config) do
      {:ok,
       %{
         config
         | ledger_file_reader: %{
             ledger_file_reader
             | options: %{length: record_file_name_length, padding: ledger_file_reader_padding}
           },
           index_file_reader: %{
             index_file_reader
             | options: %{length: record_file_name_length, padding: index_file_reader_padding}
           },
           storage: %{
             storage
             | options: %{path: path}
           }
       }}
    end
  end

  @hash_algorithm_bit_length %{
    md5: 128,
    sha: 160,
    sha256: 256,
    sha512: 512,
    sha3_256: 256,
    sha3_512: 512,
    blake2b: 512,
    blake2s: 256
  }

  @encoding_bits_per_byte %{
    base16: 4,
    base32: 5,
    base64url: 6
  }

  defp compute_record_file_name_length(%{record_file_name: record_file_name} = config) do
    case record_file_name do
      %{family: :event_id} ->
        compute_record_file_name_length_by_event_id(config)

      %{family: :hash, options: %{algorithm: algorithm, encoding: encoding}} ->
        full_bytes =
          div(@hash_algorithm_bit_length[algorithm], @encoding_bits_per_byte[encoding])

        partial_bytes =
          if Integer.mod(
               @hash_algorithm_bit_length[algorithm],
               @encoding_bits_per_byte[encoding]
             ) > 0,
             do: 1,
             else: 0

        {:ok, full_bytes + partial_bytes}

      _ ->
        {:error, {:unknown_record_file_name_length, record_file_name}}
    end
  end

  defp compute_record_file_name_length_by_event_id(%{event_id: event_id}) do
    case event_id do
      %{family: :uuid} ->
        {:ok, 32}

      _ ->
        {:error, {:unknown_event_id, event_id}}
    end
  end

  defp compute_index_file_reader_padding(%{index_file_encoder: encoder}) do
    case encoder do
      %{family: :delimited, options: %{delimiter: :lf}} -> {:ok, 1}
      %{family: :delimited, options: %{delimiter: :rs}} -> {:ok, 1}
      %{family: :delimited, options: %{delimiter: :crlf}} -> {:ok, 2}
      _undefined -> {:error, {:unknown_ledger_file_reader_padding, encoder}}
    end
  end

  defp compute_ledger_file_reader_padding(%{ledger_file_encoder: encoder}) do
    case encoder do
      %{family: :delimited, options: %{delimiter: :lf}} -> {:ok, 1}
      %{family: :delimited, options: %{delimiter: :rs}} -> {:ok, 1}
      %{family: :delimited, options: %{delimiter: :crlf}} -> {:ok, 2}
      _undefined -> {:error, {:unknown_ledger_file_reader_padding, encoder}}
    end
  end
end
