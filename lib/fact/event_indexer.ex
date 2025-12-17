defmodule Fact.EventIndexer do
  @moduledoc """
  Base behaviour and macro for building event indexers.

  `Fact.EventIndexer` defines the callback and GenServer scaffolding used by
  all event indexers in the `Fact` event storage system. An indexer listens
  for new events, extracts one or more index keys from each event, and writes
  those relationships into storage. This enables fast lookup of events by
  category, type, tag, stream, or any domain-specific attribute.

  ## Behaviour

  An indexer must implement the `c:index_event/2` callback, which extracts an
  index key from a given event. The returned value determines how the event is
  indexed:

    * a **string** — single index key  
    * a **list of strings** — multiple keys  
    * `nil` — event will not be indexed

  The `__using__/1` macro injects the full GenServer implementation that:

    * initializes and ensures the index exists
    * rebuilds the index from history on startup
    * subscribes to live event notifications
    * updates the index as new events arrive
    * responds to stream queries from other processes

  Custom indexers only need to implement the callback and optionally define
  module attributes through `use Fact.EventKeys`.

  ## Example

      defmodule MyApp.UserEmailIndexer do
        use Fact.EventIndexer

        @impl true
        def index_event(%{"data" => %{"email" => email}}, _opts), do: email
        def index_event(_, _), do: nil
      end

  """
  @callback index_event(event :: map(), state :: term()) :: list(String.t()) | String.t() | nil

  defmacro __using__(_opts \\ []) do
    quote do
      @behaviour Fact.EventIndexer

      use GenServer
      use Fact.EventKeys

      require Logger

      defstruct [:instance, :index, :index_opts]

      @doc """
      Starts the indexer process.

      Accepts both indexer-specific options and `GenServer.start_link/3`
      options. Indexer options include:

        * `:instance` — the storage instance (required)
        * `:key` — optional secondary key used in parameterized indexers
        * `:encoding` — the index encoding format (`:raw` by default)
        * `:opts` — custom options forwarded to `index_event/2`

      The index name is automatically derived from the module or
      `{module, key}` tuple for parameterized indexers.
      """
      def start_link(opts \\ []) do
        {indexer_opts, start_opts} =
          Keyword.split(opts, [:instance, :key, :opts])

        index =
          case Keyword.fetch(indexer_opts, :key) do
            {:ok, key} -> {__MODULE__, key}
            :error -> __MODULE__
          end

        instance = Keyword.fetch!(indexer_opts, :instance)

        custom_opts = Keyword.get(indexer_opts, :opts, [])

        index_opts =
          case index do
            {_mod, key} -> Keyword.put(custom_opts, :key, key)
            _ -> custom_opts
          end

        state = %__MODULE__{
          instance: instance,
          index: index,
          index_opts: index_opts
        }

        GenServer.start_link(__MODULE__, state, start_opts)
      end

      @impl true
      def init(%{instance: instance, index: index} = state) do
        :ok = ensure_storage(state)
        {:ok, state, {:continue, :rebuild_and_join}}
      end

      @impl true
      def handle_continue(:rebuild_and_join, %{instance: instance, index: index} = state) do
        rebuild_index(state)
        :ok = Fact.EventPublisher.subscribe(instance, :all)
        notify_ready(state)
        {:noreply, state}
      end

      @impl true
      def handle_info({:event_record, {_, event} = record}, state) do
        append_index(record, state)
        {:noreply, state}
      end

      @impl true
      @doc """
      Handles synchronous calls from clients requesting event IDs for a given
      index key.

      This is used by `Fact.Storage.read_index/4` and similar APIs.
      """
      def handle_cast(
            {:stream!, value, caller, direction},
            %{instance: instance, index: index} = state
          ) do
        event_ids = Fact.Storage.read_index(instance, index, value, direction)
        GenServer.reply(caller, event_ids)
        {:noreply, state}
      end

      defp notify_ready(%{instance: instance, index: index}) do
        GenServer.cast(
          Fact.Instance.event_indexer_manager(instance),
          {:indexer_ready, self(), index}
        )
      end

      defp rebuild_index(%{instance: instance, index: index} = state) do
        position = Fact.Storage.read_checkpoint(instance, index)

        Fact.EventReader.read(instance, :all, position: position)
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

      defp ensure_storage(%{instance: instance, index: index} = state) do
        checkpoint_path = Fact.Instance.indexer_checkpoint_path(instance, index)

        with :ok <- File.mkdir_p(Path.dirname(checkpoint_path)) do
          unless File.exists?(checkpoint_path),
            do: File.write(checkpoint_path, "0"),
            else: :ok
        end
      end
    end
  end
end
