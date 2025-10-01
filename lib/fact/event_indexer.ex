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
      import Fact.Names
      require Logger

      defstruct [:instance, :index, :index_opts, :encoding]

      def start_link(opts \\ []) do
        {indexer_opts, start_opts} =
          Keyword.split(opts, [:instance, :key, :encoding, :opts])

        index =
          case Keyword.fetch(indexer_opts, :key) do
            {:ok, key} -> {__MODULE__, key}
            :error -> __MODULE__
          end

        instance = Keyword.fetch!(indexer_opts, :instance)
        encoding = Keyword.get(indexer_opts, :encoding, :raw)

        custom_opts = Keyword.get(indexer_opts, :opts, [])

        index_opts =
          case index do
            {_mod, key} -> Keyword.put(custom_opts, :key, key)
            _ -> custom_opts
          end

        state = %__MODULE__{
          instance: instance,
          index: index,
          index_opts: index_opts,
          encoding: encoding
        }

        start_opts = Keyword.put_new(start_opts, :name, via(instance, __MODULE__))

        GenServer.start_link(__MODULE__, state, start_opts)
      end

      @impl true
      def init(%{instance: instance, index: index, encoding: encoding} = state) do
        Fact.Storage.ensure_index!(instance, index, encoding)
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
            %{instance: instance, index: index} = state
          ) do
        event_ids = Fact.Storage.read_index(instance, index, value, stream_opts)
        GenServer.reply(caller, event_ids)
        {:noreply, state}
      end

      @impl true
      def handle_cast(
            {:last_position, value, caller},
            %{instance: instance, index: index} = state
          ) do
        last_pos = Fact.Storage.line_count(instance, index, value)
        GenServer.reply(caller, last_pos)
        {:noreply, state}
      end

      defp notify_ready(%{instance: instance, index: index}) do
        GenServer.cast(via(instance, Fact.EventIndexerManager), {:indexer_ready, self(), index})
      end

      defp rebuild_index(%{instance: instance, index: index} = state) do
        position = Fact.Storage.read_checkpoint(instance, index)

        Fact.EventReader.read(instance, :all, from_position: position)
        |> Stream.each(&append_index(&1, state))
        |> Stream.run()
      end

      defp append_index({event_id, event} = _record, %{
             instance: instance,
             index: index,
             index_opts: index_opts
           }) do
        index_key = index_event(event, index_opts)
        Fact.Storage.write_index(instance, index, index_key, event_id)
        Fact.Storage.write_checkpoint(instance, index, event[@event_store_position])
      end
    end
  end
end
