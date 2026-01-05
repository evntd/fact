defmodule Mix.Tasks.Fact.Create do
  @moduledoc """
  Creates a new database.

  ### Usage
      

  ### Options
    
  There are a lot of options to control how the database stores information. However many of these options currently
  only support a single value. Each represents a **seam** within the system, and each can be supplied with a set of
  implementation specific options. Each seam implementation is configured using `{family}@{version}` format, while
  options are specified using a comma-delimited list of key value pairs `{key1}={value1},{key2}={value2}`.
    
  Maybe this all just a big old YAGNI...but I think it will prove its worth in time.

  #### Event options

    * `--event-id` - Controls how event ids are generated. (default: `uuid@4`)
    * `--event-id-options` - Configuration options for the selected event id format. (default: `""`)
    * `--event-schema` - Controls the schema of events. (default: `standard@1`)
    * `--event-schema-options` - Configuration options for the selected event schema. (default: `""`)

  #### Index file options
    
    * `--index-file-decoder` - Controls how record are decoded after reading. (default: `raw@1`)  
    * `--index-file-decoder-options` - Configuration options for the selected record file decoder. (default: `""`)
    * `--index-file-encoder` - Controls how record are encoded for writing. (default: `delimited@1`)
    * `--index-file-encoder-options` - Configuration options for the selected record file encoder. (default: `""`)
    * `--index-file-name` - Controls how record files are named. (default: `raw@1`)
    * `--index-file-name-options` - Configuration options for the selected record file name seam. (default: `""`) 
    * `--index-file-reader` - Controls how record files are read. (default: `fixed_length@1`)
    * `--index-file-reader-options` - Configuration options for the selected record file reader. (default: `""`)
    * `--index-file-writer` - Controls how record files are written. (default: `standard@1`)
    * `--index-file-writer-options` - Configuration options for the selected record file writer. (default: `""`)
    
  #### Index checkpoint file options 

    * `--index-checkpoint-file-decoder` - Controls how record are decoded after reading. (default: `integer@1`)
    * `--index-checkpoint-file-decoder-options` - Configuration options for the selected record file decoder. (default: `""`)
    * `--index-checkpoint-file-encoder` - Controls how record are encoded for writing. (default: `integer@1`)
    * `--index-checkpoint-file-encoder-options` - Configuration options for the selected record file encoder. (default: `""`)
    * `--index-checkpoint-file-name` - Controls how record files are named. (default: `fixed@1`)
    * `--index-checkpoint-file-name-options` - Configuration options for the selected record file name seam. (default: `""`) 
    * `--index-checkpoint-file-reader` - Controls how record files are read. (default: `full@1`)
    * `--index-checkpoint-file-reader-options` - Configuration options for the selected record file reader. (default: `""`)
    * `--index-checkpoint-file-writer` - Controls how record files are written. (default: `standard@1`)
    * `--index-checkpoint-file-writer-options` - Configuration options for the selected record file writer. (default: `""`)    

  #### Ledger file options

    * `--ledger-file-decoder` - Controls how record are decoded after reading. (default: `raw@1`)
    * `--ledger-file-decoder-options` - Configuration options for the selected record file decoder. (default: `""`)
    * `--ledger-file-encoder` - Controls how record are encoded for writing. (default: `delimited@1`)
    * `--ledger-file-encoder-options` - Configuration options for the selected record file encoder. (default: `""`)
    * `--ledger-file-name` - Controls how record files are named. (default: `fixed@1`)
    * `--ledger-file-name-options` - Configuration options for the selected record file name seam. (default: `""`) 
    * `--ledger-file-reader` - Controls how record files are read. (default: `fixed_length@1`)
    * `--ledger-file-reader-options` - Configuration options for the selected record file reader. (default: `""`)
    * `--ledger-file-writer` - Controls how record files are written. (default: `standard@1`)
    * `--ledger-file-writer-options` - Configuration options for the selected record file writer. (default: `""`)

  #### Lock file options

    * `--lock-file-decoder` - Controls how record are decoded after reading. (default: `json@1`)
    * `--lock-file-decoder-options` - Configuration options for the selected record file decoder. (default: `""`)
    * `--lock-file-encoder` - Controls how record are encoded for writing. (default: `json@1`)
    * `--lock-file-encoder-options` - Configuration options for the selected record file encoder. (default: `""`)
    * `--lock-file-name` - Controls how record files are named. (default: `fixed@1`)
    * `--lock-file-name-options` - Configuration options for the selected record file name seam. (default: `""`) 
    * `--lock-file-reader` - Controls how record files are read. (default: `full@1`)
    * `--lock-file-reader-options` - Configuration options for the selected record file reader. (default: `""`)
    * `--lock-file-writer` - Controls how record files are written. (default: `standard@1`)
    * `--lock-file-writer-options` - Configuration options for the selected record file writer. (default: `""`)  

  #### Record file options
    
    * `--record-file-decoder` - Controls how record are decoded after reading. (default: `json@1`)
    * `--record-file-decoder-options` - Configuration options for the selected record file decoder. (default: `""`)
    * `--record-file-encoder` - Controls how record are encoded for writing. (default: `json@1`)
    * `--record-file-encoder-options` - Configuration options for the selected record file encoder. (default: `""`)
    * `--record-file-name` - Controls how record files are named. (default: `event_id@1`)
    * `--record-file-name-options` - Configuration options for the selected record file name seam. (default: `""`) 
    * `--record-file-reader` - Controls how record files are read. (default: `full@1`)
    * `--record-file-reader-options` - Configuration options for the selected record file reader. (default: `""`)
    * `--record-file-writer` - Controls how record files are written. (default: `standard@1`)
    * `--record-file-writer-options` - Configuration options for the selected record file writer. (default: `""`)
    
  #### Storage options
    
    * `--storage` - Controls how the files are organized within the file system. (default: `standard@1`)
    * `--storage-options` - Configuration options for the selected storage. (default: `""`)

  """

  use Mix.Task

  @switches [
    name: :string,
    path: :string,
    event_id: :string,
    event_id_options: :string,
    event_schema: :string,
    event_schema_options: :string,
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
    record_file_writer: :string,
    record_file_writer_options: :string,
    storage: :string,
    storage_options: :string
  ]

  @aliases [
    n: :name,
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
