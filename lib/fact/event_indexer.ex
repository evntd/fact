defmodule Fact.EventIndexer do
  @moduledoc """
  Base behaviour and macro for building event indexers.

  `Fact.EventIndexer` defines the callbacks and GenServer scaffolding shared by all event indexers in the `Fact` storage
  system. An indexer listens for new events and extracts zero, one, or many values from each even it processes. For each
  extracted value, the indexer create or appends to a file, recording the event's `t:Fact.Types.record_id/0`.
    
  Indexers are just event projections, that filter the event ledger, and produce keyed, ordered sets of events.
    
  > #### Safe to Delete {: .info}
  >
  > It's safe to delete any of index files and folders written to the file system, **when the system is not operating**.
  > They will be recreated, the next time indexer is started.

  ## Behaviour

  An indexer must implement the `c:index_event/2` callback, which extracts values from the supplied event.

  The `__using__/1` macro injects the full GenServer implementation that:

    * initializes and ensures the index exists
    * rebuilds the index from history on startup
    * subscribes to live event notifications
    * updates the index as new events arrive

    
  ## Custom Indexers

  Custom indexers only need to implement the callback.

  ### Examples
    
  This would produce an index for every user, including all the events which define a `user_id` in the event data.

      defmodule YourApp.UserIndexer do
        use Fact.EventIndexer

        @impl true
        def index_event(%{@event_data => %{"user_id" => user_id}}, _opts), 
          do: to_string(user_id)
        
        def index_event(_, _), do: nil
      end
    
  This would produce an index for every tenant, including all the events which define a `tenant_id` in the event 
  metadata.
    
      defmodule YourApp.TenantIndexer do
        use Fact.EventIndexer
        def index_event(%{@event_metadata => %{"tenant_id" => tenant_id}}, _opts), 
          do: to_string(tenant_id)
        
        def index_event(_, _), do: nil        
      end

  """

  @type indexed_message ::
          {:indexed,
           %{
             required(:indexer) => Fact.Types.indexer(),
             required(:position) => Fact.Types.event_position(),
             required(:index_values) => list(Fact.Types.index_value())
           }}

  @doc """
  Called when an event needs to be indexed. 
  """
  @callback index_event(event :: Fact.Types.event_record(), state :: term()) ::
              Fact.Type.index_value() | list(Fact.Type.index_value()) | nil

  @doc """
  Subscribe to messages published by the specified indexer. 
    
  ## Messages
    
    * `t:Fact.EventIndexer.indexed_message/0` - published whenever any `t:Fact.Types.event_record/0` is processed 
    regardless of whether the event is included within the index.
  """
  @spec subscribe(Fact.Instance.t(), Fact.Types.indexer()) :: :ok
  def subscribe(%Fact.Instance{} = instance, indexer) do
    Phoenix.PubSub.subscribe(Fact.Instance.pubsub(instance), topic(indexer))
  end

  defp topic(indexer) do
    case indexer do
      {indexer_mod, indexer_key} ->
        "#{indexer_mod}:#{indexer_key}"

      indexer ->
        to_string(indexer)
    end
  end

  defmacro __using__(_opts \\ []) do
    quote do
      @behaviour Fact.EventIndexer

      use GenServer
      use Fact.Types

      require Logger

      defstruct [:instance, :index, :index_opts, :checkpoint]

      @doc """
      Starts the indexer process.

      Accepts both indexer-specific options and `GenServer.start_link/3`
      options. Indexer options include:

        * `:instance` — the storage instance (required)
        * `:key` — optional secondary `t:Fact.Types.indexer_key/0` used for partitioned indexers
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
          index_opts: index_opts,
          checkpoint: 0
        }

        GenServer.start_link(__MODULE__, state, start_opts)
      end

      @impl true
      @doc false
      def init(%{instance: instance, index: index} = state) do
        :ok = ensure_storage(state)
        :ok = Fact.EventPublisher.subscribe(instance, :all)
        {:ok, state, {:continue, :rebuild_and_join}}
      end

      @impl true
      @doc false
      def handle_continue(:rebuild_and_join, %{instance: instance, index: index} = state) do
        checkpoint = rebuild_index(state)
        Fact.EventIndexerManager.notify_ready(instance, index, checkpoint)
        {:noreply, %{state | checkpoint: checkpoint}}
      end

      @impl true
      @doc false
      def handle_info(
            {:event_record, {_, %{@event_store_position => position} = event} = record},
            %{checkpoint: checkpoint} = state
          ) do
        unindexed = position - checkpoint

        new_checkpoint =
          cond do
            unindexed > 1 ->
              rebuild_index(state)

            unindexed == 1 ->
              append_index(record, state)

            unindexed <= 0 ->
              checkpoint
          end

        {:noreply, %{state | checkpoint: new_checkpoint}}
      end

      defp rebuild_index(%{instance: instance, index: index} = state) do
        initial_checkpoint = Fact.Storage.read_checkpoint(instance, index)

        Fact.Storage.read_ledger(instance, position: initial_checkpoint, return_type: :record)
        |> Enum.reduce(initial_checkpoint, fn record, _acc -> append_index(record, state) end)
      end

      defp append_index({record_id, %{@event_store_position => position} = event} = _record, %{
             instance: instance,
             index: indexer,
             index_opts: index_opts
           }) do
        index_values = index_event(event, index_opts)
        Fact.Storage.write_index(instance, indexer, index_values, record_id)
        Fact.Storage.write_checkpoint(instance, indexer, position)
        publish_indexed(instance, indexer, position, index_values)
        position
      end

      defp ensure_storage(%{instance: instance, index: index} = state) do
        checkpoint_path = Fact.Instance.indexer_checkpoint_path(instance, index)

        with :ok <- File.mkdir_p(Path.dirname(checkpoint_path)) do
          unless File.exists?(checkpoint_path),
            do: File.write(checkpoint_path, "0"),
            else: :ok
        end
      end

      defp publish_indexed(%Fact.Instance{} = instance, indexer, position, index_values) do
        Phoenix.PubSub.broadcast(
          Fact.Instance.pubsub(instance),
          topic(indexer),
          {:indexed,
           %{indexer: indexer, position: position, index_values: List.wrap(index_values)}}
        )
      end

      defp topic(indexer) do
        case indexer do
          {indexer_mod, indexer_key} ->
            "#{indexer_mod}:#{indexer_key}"

          indexer ->
            to_string(indexer)
        end
      end
    end
  end
end
