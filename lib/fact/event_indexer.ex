defmodule Fact.EventIndexer do
  @moduledoc """
  Base module for all indexers.
  """
  @callback index_event(event :: map(), state :: term()) :: List.t(String.t()) | String.t() | nil

  defmacro __using__(_opts \\ []) do
    quote do
      @behaviour Fact.EventIndexer

      use GenServer
      use Fact.EventKeys
      require Logger

      defstruct [:index, :path, :encoding, :opts]

      def start_link(opts \\ []) do
        {indexer_opts, start_opts} = Keyword.split(opts, [:key, :path, :encoding, :opts])

        index =
          case Keyword.fetch(indexer_opts, :key) do
            {:ok, key} -> {__MODULE__, key}
            :error -> __MODULE__
          end

        base = Keyword.fetch!(indexer_opts, :path)
        encoding = Keyword.get(indexer_opts, :encoding, :raw)
        custom_opts = Keyword.get(indexer_opts, :opts, [])

        index_opts =
          case index do
            {_mod, key} -> Keyword.put(custom_opts, :key, key)
            _ -> custom_opts
          end

        path =
          case index do
            {_mod, key} -> Path.join(base, to_string(key))
            _ -> base
          end

        state = %__MODULE__{
          index: index,
          path: path,
          encoding: encoding,
          opts: opts
        }

        start_opts = Keyword.put_new(start_opts, :name, __MODULE__)
        GenServer.start_link(__MODULE__, state, start_opts)
      end

      @impl true
      def init(state) do
        ensure_paths!(state.path)
        {:ok, state, {:continue, :rebuild_and_join}}
      end

      @impl true
      def handle_continue(:rebuild_and_join, state) do
        checkpoint = load_checkpoint(state.path)
        Logger.debug("#{__MODULE__} building index from #{@event_store_position} #{checkpoint}")

        Fact.EventReader.read(:all, from_position: checkpoint)
        |> Stream.each(fn {event_id, event} = record ->
          append_to_index(record, state)
          save_checkpoint(event[@event_store_position], state.path)
        end)
        |> Stream.run()

        Logger.debug("#{__MODULE__} joining :fact_indexers group")
        :ok = :pg.join(:fact_indexers, self())

        send(Fact.EventIndexerManager, {:indexer_ready, self(), state.index})

        {:noreply, state}
      end

      @impl true
      def handle_info({:index, {_, event} = record}, state) do
        append_to_index(record, state)
        save_checkpoint(event[@event_store_position], state.path)
        {:noreply, state}
      end

      @impl true
      def handle_cast(
            {:stream!, value, caller, opts},
            %__MODULE__{index: index, path: path, encoding: encoding} = state
          ) do
        index_path = Path.join(path, encode_key(value, encoding))
        direction = Keyword.get(opts, :direction, :forward)

        event_ids =
          case {File.exists?(index_path), direction} do
            {false, _} -> Stream.concat([])
            {true, :forward} -> Fact.Storage.read_index_forward(index_path)
            {true, :backward} -> Fact.Storage.read_index_backward(index_path)
          end

        GenServer.reply(caller, event_ids)

        {:noreply, state}
      end

      @impl true
      def handle_cast({:last_position, value, caller}, %{encoding: encoding, path: path} = state) do
        file = Path.join(path, encode_key(value, encoding))

        last_pos =
          case File.exists?(file) do
            false -> 0
            true -> File.stream!(file) |> Enum.count()
          end

        GenServer.reply(caller, last_pos)

        {:noreply, state}
      end

      defp append_to_index({event_id, event} = _record, %__MODULE__{
             index: index,
             path: path,
             encoding: encoding,
             opts: opts
           }) do
        case index_event(event, opts) do
          nil ->
            :ignored

          [] ->
            :ignored

          key when is_binary(key) ->
            file = Path.join(path, encode_key(key, encoding))
            File.write!(file, event_id <> "\n", [:append])
            :ok

          keys when is_list(keys) ->
            line = event_id <> "\n"

            Enum.each(keys, fn key ->
              file = Path.join(path, encode_key(key, encoding))
              File.write!(file, line, [:append])
            end)
        end
      end

      defp load_checkpoint(path) do
        checkpoint_path = get_checkpoint_path(path)

        case File.read(checkpoint_path) do
          {:ok, contents} -> contents |> String.trim() |> String.to_integer()
          {:error, _} -> 0
        end
      end

      defp save_checkpoint(position, path) do
        get_checkpoint_path(path)
        |> File.write!(Integer.to_string(position))
      end

      defp ensure_paths!(path) do
        File.mkdir_p!(path)
        checkpoint_path = get_checkpoint_path(path)
        unless File.exists?(checkpoint_path), do: File.write!(checkpoint_path, "0")
      end

      defp get_checkpoint_path(path), do: Path.join(path, ".checkpoint")

      defp encode_key(value, encoding) do
        case encoding do
          :raw ->
            to_string(value)

          :hash ->
            :crypto.hash(:sha, to_string(value))
            |> Base.encode16(case: :lower)

          {:hash, algo} ->
            :crypto.hash(algo, to_string(value))
            |> Base.encode16(case: :lower)

          other ->
            raise ArgumentError, "unsupported encoding: #{inspect(other)}"
        end
      end
    end
  end
end
