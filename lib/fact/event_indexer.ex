defmodule Fact.EventIndexer do
  @moduledoc """
  Base module for all indexers.
  """
  @callback index_event(event :: map(), state :: term()) :: List.t(String.t()) | String.t() | nil

  defmacro __using__(opts \\ []) do
    index_dir = Keyword.fetch!(opts, :path) |> to_string

    quote do
      @behaviour Fact.EventIndexer

      use GenServer
      use Fact.EventKeys
      import Fact.Names
      require Logger

      @index_dir unquote(index_dir)
      @checkpoint_file ".checkpoint"
      @checkpoint_init 0

      defstruct [:instance, :index, :index_opts, :checkpoint_path, :encoding, :encode_path]

      def start_link(opts \\ []) do
        {indexer_opts, start_opts} =
          Keyword.split(opts, [:instance, :key, :path, :encoding, :opts])

        index =
          case Keyword.fetch(indexer_opts, :key) do
            {:ok, key} -> {__MODULE__, key}
            :error -> __MODULE__
          end

        instance = Keyword.fetch!(indexer_opts, :instance)
        base_path = Keyword.fetch!(indexer_opts, :path)
        encoding = Keyword.get(indexer_opts, :encoding, :raw)
        custom_opts = Keyword.get(indexer_opts, :opts, [])

        index_opts =
          case index do
            {_mod, key} -> Keyword.put(custom_opts, :key, key)
            _ -> custom_opts
          end

        path =
          case index do
            {_mod, key} -> Path.join([base_path, @index_dir, to_string(key)])
            _ -> Path.join(base_path, @index_dir)
          end

        state = %__MODULE__{
          instance: instance,
          index: index,
          index_opts: index_opts,
          checkpoint_path: Path.join(path, @checkpoint_file),
          encode_path: path_encoder(path, encoding)
        }

        start_opts = Keyword.put_new(start_opts, :name, via(instance, __MODULE__))

        GenServer.start_link(__MODULE__, state, start_opts)
      end

      @impl true
      def init(%{checkpoint_path: checkpoint_path} = state) do
        Fact.Storage.ensure_file!(checkpoint_path, @checkpoint_init)
        {:ok, state, {:continue, :rebuild_and_join}}
      end

      @impl true
      def handle_continue(:rebuild_and_join, %{instance: instance, index: index} = state) do
        rebuild_index(state)
        :ok = Fact.EventPublisher.subscribe(instance, self())
        notify_ready(state)
        {:noreply, state}
      end

      @impl true
      def handle_info({:appended, {_, event} = record}, state) do
        append_index(record, state)
        {:noreply, state}
      end

      @impl true
      def handle_cast(
            {:stream!, value, caller, stream_opts},
            %{instance: instance, index: index, encode_path: encode_path} = state
          ) do
        index_path = encode_path.(value)
        direction = Keyword.get(stream_opts, :direction, :forward)
        event_ids = read_index(instance, index_path, direction)
        GenServer.reply(caller, event_ids)
        {:noreply, state}
      end

      @impl true
      def handle_cast({:last_position, value, caller}, %{encode_path: encode_path} = state) do
        file = encode_path.(value)
        last_pos = Fact.Storage.line_count(file)
        GenServer.reply(caller, last_pos)
        {:noreply, state}
      end

      defp notify_ready(%{instance: instance, index: index}) do
        GenServer.cast(via(instance, Fact.EventIndexerManager), {:indexer_ready, self(), index})
      end

      defp rebuild_index(%{instance: instance, checkpoint_path: checkpoint_path} = state) do
        position = Fact.Storage.read_checkpoint(checkpoint_path)

        Fact.EventReader.read(instance, :all, from_position: position)
        |> Stream.each(&append_index(&1, state))
        |> Stream.run()
      end

      defp append_index({event_id, event} = _record, %{
             index: index,
             index_opts: index_opts,
             encode_path: encode_path,
             checkpoint_path: checkpoint_path
           }) do
        index_event(event, index_opts) |> write_index(event_id, encode_path)
        Fact.Storage.write_checkpoint(checkpoint_path, event[@event_store_position])
      end

      defp read_index(instance, path, :forward),
        do: Fact.Storage.read_index_forward(instance, path)

      defp read_index(instance, path, :backward),
        do: Fact.Storage.read_index_backward(instance, path)

      defp write_index(nil, _event_id, _encode_path), do: :ignored
      defp write_index([], _event_id, _encode_path), do: :ignored

      defp write_index(index_key, event_id, encode_path) when is_binary(index_key) do
        encode_path.(index_key)
        |> Fact.Storage.write_index(event_id)
      end

      defp write_index(index_keys, event_id, encode_path) when is_list(index_keys) do
        index_keys
        |> Enum.map(&encode_path.(&1))
        |> Enum.each(&Fact.Storage.write_index(&1, event_id))
      end

      defp path_encoder(path, encoding) do
        fn key -> Path.join(path, encode_key(key, encoding)) end
      end

      defp encode_key(value, :raw), do: to_string(value)
      defp encode_key(value, :hash), do: encode_key(value, {:hash, :sha})

      defp encode_key(value, {:hash, algo}),
        do: :crypto.hash(algo, to_string(value)) |> Base.encode16(case: :lower)

      defp encode_key(value, encoding),
        do: raise(ArgumentError, "unsupported encoding: #{inspect(encoding)}")
    end
  end
end
