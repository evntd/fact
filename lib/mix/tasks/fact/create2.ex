defmodule Mix.Tasks.Fact.Create2 do
  @moduledoc false

  use Mix.Task

  @switches [
    name: :string,
    path: :string,
    event_id: :string,
    event_id_options: :string,
    index_checkpoint_file_decoder: :string,
    index_checkpoint_file_decoder_options: :string,
    index_checkpoint_file_encoder: :string,
    index_checkpoint_file_encoder_options: :string,
    index_checkpoint_file_name: :string,
    index_checkpoint_file_name_options: :string,
    index_checkpoint_file_reader: :string,
    index_checkpoint_file_reader_options: :string,
    index_checkpoint_file_writer: :string,
    index_checkpoint_file_writer_options: :string,
    index_file_decoder: :string,
    index_file_decoder_options: :string,
    index_file_encoder: :string,
    index_file_encoder_options: :string,
    index_file_name: :string,
    index_file_name_options: :string,
    index_file_reader: :string,
    index_file_reader_options: :string,
    index_file_writer: :string,
    index_file_writer_options: :string,
    ledger_file_decoder: :string,
    ledger_file_decoder_options: :string,
    ledger_file_encoder: :string,
    ledger_file_encoder_options: :string,
    ledger_file_name: :string,
    ledger_file_name_options: :string,
    ledger_file_reader: :string,
    ledger_file_reader_options: :string,
    ledger_file_writer: :string,
    ledger_file_writer_options: :string,
    record_file_decoder: :string,
    record_file_decoder_options: :string,
    record_file_encoder: :string,
    record_file_encoder_options: :string,
    record_file_name: :string,
    record_file_name_options: :string,
    record_file_reader: :string,
    record_file_reader_options: :string,
    record_file_schema: :string,
    record_file_schema_options: :string,
    record_file_writer: :string,
    record_file_writer_options: :string,
    storage_layout: :string,
    storage_layout_options: :string
  ]

  @aliases [
    n: :name,
    p: :path
  ]

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
    record_file_decoder: Fact.RecordFile.Decoder,
    record_file_encoder: Fact.RecordFile.Encoder,
    record_file_name: Fact.RecordFile.Name,
    record_file_reader: Fact.RecordFile.Reader,
    record_file_schema: Fact.RecordFile.Schema,
    record_file_writer: Fact.RecordFile.Writer,
    storage_layout: Fact.StorageLayout
  }

  @impl true
  def run(args) do
    {parsed, argv, invalid} = OptionParser.parse(args, strict: @switches, aliases: @aliases)

    if invalid != [] do
      Mix.raise("Invalid options: #{inspect(invalid)}")
    end

    if argv != [] do
      Mix.raise("Unexpected arguments: #{Enum.join(argv, " ")}")
    end

    {:ok, config} = build_configuration(parsed)

    Mix.shell().info("\nResolved configuration:\n")
    IO.inspect(config, pretty: true)

    :ok
  end

  defp build_configuration(parsed) do
    {:ok, config} =
      Enum.reduce_while(
        @abstractions,
        {:ok, %{name: Keyword.get(parsed, :name), path: Keyword.get(parsed, :path)}},
        fn {key, abstraction}, {:ok, acc} ->
          case resolve(parsed, key, abstraction) do
            {:ok, config} ->
              {:cont, {:ok, Map.put(acc, key, config)}}

            {:error, reason} ->
              {:halt, {:error, key, reason}}
          end
        end
      )

    handle_computed_configurations(config)
  end

  def resolve(parsed, key, abstraction) do
    with {:ok, parsed_impl_id} <- parse_impl_id(Keyword.get(parsed, key)),
         {:ok, parsed_impl_opts} <- parse_impl_options(Keyword.get(parsed, :"#{key}_options")),
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
         %{ledger_file_reader: ledger_file_reader, index_file_reader: index_file_reader} = config
       ) do
    # This feels so gross, but I'm a bit stuck on some of the implicit coupling,
    # and don't want to introduce a ton of extra complexity, there is plenty already.

    with {:ok, record_file_name_length} <- compute_record_file_name_length(config),
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
