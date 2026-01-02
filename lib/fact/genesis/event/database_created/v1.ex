defmodule Fact.Genesis.Event.DatabaseCreated.V1 do
  @keys [
    :database_id,
    :elixir_version,
    :erts_version,
    :fact_version,
    :os_version,
    :otp_version,
    :event_id,
    :index_checkpoint_file_decoder,
    :index_checkpoint_file_encoder,
    :index_checkpoint_file_name,
    :index_checkpoint_file_reader,
    :index_checkpoint_file_writer,
    :index_file_decoder,
    :index_file_encoder,
    :index_file_name,
    :index_file_reader,
    :index_file_writer,
    :ledger_file_decoder,
    :ledger_file_encoder,
    :ledger_file_name,
    :ledger_file_reader,
    :ledger_file_writer,
    :record_file_decoder,
    :record_file_encoder,
    :record_file_name,
    :record_file_reader,
    :record_file_schema,
    :record_file_writer,
    :storage_layout
  ]

  @enforce_keys @keys
  defstruct @keys

  @type component_config :: %{
          required(:family) => :atom,
          required(:version) => :positive_integer,
          required(:options) => map()
        }

  @type t :: %__MODULE__{
          database_id: Fact.Types.database_id(),
          elixir_version: String.t(),
          erts_version: String.t(),
          fact_version: String.t(),
          os_version: String.t(),
          otp_version: String.t(),
          event_id: component_config(),
          index_checkpoint_file_decoder: component_config(),
          index_checkpoint_file_encoder: component_config(),
          index_checkpoint_file_name: component_config(),
          index_checkpoint_file_reader: component_config(),
          index_checkpoint_file_writer: component_config(),
          index_file_decoder: component_config(),
          index_file_encoder: component_config(),
          index_file_name: component_config(),
          index_file_reader: component_config(),
          index_file_writer: component_config(),
          ledger_file_decoder: component_config(),
          ledger_file_encoder: component_config(),
          ledger_file_name: component_config(),
          ledger_file_reader: component_config(),
          ledger_file_writer: component_config(),
          record_file_decoder: component_config(),
          record_file_encoder: component_config(),
          record_file_name: component_config(),
          record_file_reader: component_config(),
          record_file_schema: component_config(),
          record_file_writer: component_config(),
          storage_layout: component_config()
        }
end
