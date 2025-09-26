defmodule Fact.Storage.Driver do
  @moduledoc false

  @type record_id :: String.t()
  @type file_path :: String.t()

  @callback read_event(record_id) :: {record_id, map}
  @callback read_index_forward(file_path) :: Stream.t(String.t())
  @callback read_index_backward(file_path) :: Stream.t(String.t())
  @callback write_event(map) :: {:ok, record_id} | {:error, term(), record_id}

  defmacro __using__(_opts) do
    quote do
      @behaviour Fact.Storage.Driver

      @type record_id :: String.t()
      @type record_data :: String.t()

      @callback prepare_record(map) :: {record_id, record_data}
      @callback record_id_length() :: integer

      @impl true
      def read_event(record_id) do
        db_dir = Application.get_env(:fact, :db)
        path = Path.join(db_dir, record_id)
        event = File.read!(path) |> Fact.Storage.format().decode()
        {record_id, event}
      end

      @impl true
      def read_index_backward(index_path) do
        Fact.IndexFileReader.Backwards.Line.read(record_id_length(), index_path)
      end

      @impl true
      def read_index_forward(index_path) do
        File.stream!(index_path) |> Stream.map(&String.slice(&1, 0, record_id_length()))
      end

      @impl true
      def write_event(event) do
        {record_id, record} = prepare_record(event)
        path = Path.join(Application.get_env(:fact, :db), record_id)

        case File.write(path, record, [:exclusive]) do
          :ok ->
            {:ok, record_id}

          {:error, reason} ->
            {:error, reason, record_id}
        end
      end

      defoverridable read_event: 1,
                     read_index_backward: 1,
                     read_index_forward: 1,
                     write_event: 1
    end
  end
end
