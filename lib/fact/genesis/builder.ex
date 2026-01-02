defmodule Fact.Genesis.Builder do
  @moduledoc false

  alias Fact.Genesis.Event.DatabaseCreated
  alias Fact.RecordFile.Schema

  def initial_state(), do: :initial_state

  def evolve(:initial_state, %DatabaseCreated.V1{} = event) do
    with context <- Fact.Context.from_genesis(event),
         :ok <- init_storage(context) do
      genesis =
        %{}
        |> then(&Schema.set_event_type(context, &1, to_string(event.__struct__)))
        |> then(&Schema.set_event_id(context, &1, Fact.EventId.generate(context)))
        |> then(&Schema.set_event_data(context, &1, Map.from_struct(event)))
        |> then(&Schema.set_event_metadata(context, &1, %{}))
        |> then(&Schema.set_event_store_position(context, &1, 1))
        |> then(
          &Schema.set_event_store_timestamp(
            context,
            &1,
            DateTime.utc_now() |> DateTime.to_unix(:microsecond)
          )
        )
        |> then(&Schema.set_event_tags(context, &1, ["__fact__:#{event.database_id}"]))

      {:ok, record_id} = Fact.RecordFile.write(context, genesis)
      {:ok, ^record_id} = Fact.LedgerFile.write(context, record_id)

      :built
    end
  end

  defp init_storage(%Fact.Context{} = context) do
    with {:ok, path} <- Fact.StorageLayout.path(context),
         :ok <- File.mkdir_p(path),
         :ok <- File.write(Path.join(path, ".gitignore"), "*"),
         {:ok, records_path} <- Fact.StorageLayout.records_path(context),
         :ok <- File.mkdir_p(records_path),
         {:ok, indices_path} <- Fact.StorageLayout.indices_path(context),
         :ok <- File.mkdir_p(indices_path) do
      :ok
    end
  end
end
