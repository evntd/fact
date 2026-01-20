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
  """
  @doc since: "0.1.0"
  @spec let_there_be_light(%DatabaseCreated.V1{}) :: :ok
  def let_there_be_light(%DatabaseCreated.V1{} = event) do
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

      {:ok, record_id} = Fact.RecordFile.write(context, genesis)
      {:ok, ^record_id} = Fact.LedgerFile.write(context, record_id)

      # writes the bare minimum into a special .bootstrap file
      # with just enough to read the genesis event and start the system. 
      :ok = Fact.BootstrapFile.write(path, {record_id, event})

      :ok
    end
  end
end
