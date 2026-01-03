defmodule Mix.Tasks.Fact.Create2 do
  @moduledoc false

  use Mix.Task

  @switches [
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
    lock_file_decoder: :string,
    lock_file_decoder_options: :string,
    lock_file_encoder: :string,
    lock_file_encoder_options: :string,
    lock_file_name: :string,
    lock_file_name_options: :string,
    lock_file_reader: :string,
    lock_file_reader_options: :string,
    lock_file_writer: :string,
    lock_file_writer_options: :string,
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
    p: :path
  ]

  @error_messages_by_reason %{
    not_directory: "the path must be a directory",
    not_empty_directory: "the path must be an empty directory"
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

    command = %Fact.Genesis.Command.CreateDatabase.V1{args: parsed}
    state = Fact.Genesis.Decider.initial_state()

    with {:ok, events} <- Fact.Genesis.Decider.decide(state, command) do
      Enum.reduce(events, Fact.Genesis.Builder.initial_state(), fn event, state ->
        Fact.Genesis.Builder.evolve(state, event)
      end)

      Mix.shell().info("\nResults:\n#{inspect(events)}")
      :ok
    else
      {:error, reason} ->
        Mix.shell().error(
          "Database creation failed: #{Map.get(@error_messages_by_reason, reason, reason)}."
        )
    end
  end
end
