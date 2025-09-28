defmodule Fact.Storage.Driver do
  @moduledoc false

  @type record_id :: String.t()
  @type record_path :: String.t()
  @type file_path :: String.t()
  @type events_path :: String.t()

  @callback read_event(record_path) :: binary
  @callback read_index_forward(file_path) :: Stream.t(String.t())
  @callback read_index_backward(file_path) :: Stream.t(String.t())
  @callback write_event(events_path, map) :: {:ok, record_id} | {:error, term(), record_id}

  defmacro __using__(_opts) do
    quote do
      @behaviour Fact.Storage.Driver

      @type record_id :: String.t()
      @type record_data :: String.t()

      @callback prepare_record(map) :: {record_id, record_data}
      @callback record_id_length() :: integer

      @impl true
      defdelegate read_event(record_path), to: File, as: :read!

      @impl true
      def read_index_backward(index_path) do
        Fact.IndexFileReader.Backwards.Line.read(record_id_length(), index_path)
      end

      @impl true
      def read_index_forward(index_path) do
        File.stream!(index_path) |> Stream.map(&String.slice(&1, 0, record_id_length()))
      end

      @impl true
      def write_event(events_path, event) do
        {record_id, record} = prepare_record(event)
        path = Path.join(events_path, record_id)

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
                     write_event: 2
    end
  end
end
