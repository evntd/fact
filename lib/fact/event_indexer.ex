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

  @typedoc """
  The values that can be return by a `c:Fact.EventIndexer.index_event` callback function.
  """
  @type index_event_result :: Fact.Type.index_value() | list(Fact.Type.index_value()) | nil

  @typedoc """
  This describes the results of the indexing process.
  """
  @type index_result :: %{
          required(:position) => Fact.Types.event_position(),
          required(:record_id) => Fact.Types.record_id(),
          required(:index_values) => list(index_value())
        }

  @typedoc """
  The message that is published immediately after an indexer processes a `t:Fact.Types.record/0`.
  """
  @type indexed_message ::
          {:indexed, indexer_id(), index_result()}

  @typedoc """
  A module that implements the `Fact.EventIndexer` behaviour to index records.
  """
  @type indexer_module() :: :atom

  @typedoc """
  This is additional metadata for a specific `t:Fact.EventIndexer.indexer_id/0`.
    
  At the time of writing, only `Fact.EventDataIndexer` uses an `t:Fact.EventIndexer.indexer_key/0`, because there can be 
  multiple processes running, each indexing a different key within an `t:Fact.Types.event_data/0`
  """
  @type indexer_key() :: String.t()

  @typedoc """
  The value produced by an `t:Fact.EventIndexer.indexer_id/0` when indexing an `t:Fact.Types.event_record/0`. 
  """
  @type index_value() :: String.t()

  @typedoc """
  The unique identifier for an indexer.
    
  ### Built-in Indexers

    * `Fact.EventDataIndexer` - requires an `t:Fact.EventIndexer.indexer_key/0`
    * `Fact.EventStreamCategoryIndexer`
    * `Fact.EventStreamIndexer`
    * `Fact.EventStreamsByCategoryIndexer`
    * `Fact.EventStreamsIndexer`
    * `Fact.EventTagsIndexer`
    * `Fact.EventTypeIndexer`
  """
  @type indexer_id() ::
          indexer_module()
          | {indexer_module(), indexer_key()}

  @typedoc """
  Option values passed to the `c:Fact.EventIndexer.index_event/2` callback function to control the indexing of
  of records.
  """
  @type indexer_option() ::
          {:indexer_key, indexer_key()}
          | indexer_custom_option()

  @typedoc """
  Custom option values passed to the `c:Fact.EventIndexer.index_event/2` callback function to control the indexing 
  of records.
  """
  @type indexer_custom_option() :: {atom(), term()}

  @typedoc """
  Options passed to the `c:Fact.EventIndexer.index_event/2` callback function to control the indexing of records.
  """
  @type indexer_options() :: [indexer_option()]

  @typedoc """
  Option values used by the `start_link/2` functions for indexer modules.
  """
  @type start_option ::
          {:indexer_id, indexer_id()}
          | {:indexer_opts, indexer_options()}
          | GenServer.option()

  @typedoc """
  Options used by the `start_link/2` functions for indexer modules. 
  """
  @type start_options :: [start_option()]

  @typedoc """
  The state structure used by indexers in the `GenServer` callback functions. 
  """
  @type t :: %{
          required(:context) => Fact.Context.t(),
          required(:indexer) => Fact.EventIndexer.indexer_id(),
          required(:indexer_opts) => Fact.EventIndexer.indexer_options(),
          required(:checkpoint) => Fact.Types.read_position()
        }

  @doc """
  Called when an event needs to be indexed. 
  """
  @callback index_event(event :: Fact.Types.event_record(), indexer_options()) ::
              index_event_result()

  @doc """
  Subscribe to messages published by the specified indexer. 
    
  ## Messages
    
    * `t:Fact.EventIndexer.indexed_message/0` - published whenever any `t:Fact.Types.event_record/0` is processed 
    regardless of whether the event is included within the index.
  """
  @spec subscribe(Fact.Context.t(), indexer_id()) :: :ok
  def subscribe(%Fact.Context{} = context, indexer) do
    Phoenix.PubSub.subscribe(Fact.Context.pubsub(context), topic(indexer))
  end

  @doc """
  Gets the name of the topic where the indexer publishes messages. 
  """
  @spec topic(indexer_id()) :: String.t()
  def topic(indexer) do
    case indexer do
      {indexer_mod, nil} ->
        "index:#{indexer_mod}"
        
      {indexer_mod, indexer_key} ->
        "index:#{indexer_mod}:#{indexer_key}"
    end
  end

  defmacro __using__(_opts \\ []) do
    quote do
      @behaviour Fact.EventIndexer

      use GenServer
      use Fact.Types

      require Logger

      defstruct [:context, :indexer_id, :indexer_opts, :checkpoint]
      
      @spec child_spec({Fact.Context.t(), Fact.EventIndexer.start_options()}) ::
              Supervisor.child_spec()
      def child_spec(opts) do
        context = Keyword.fetch!(opts, :context)
        id = {__MODULE__, Keyword.get(opts, :key)}
        options = Keyword.get(opts, :options, [])

        %{
          id: id,
          start:
            {__MODULE__, :start_link,
             [
               [
                 context: context,
                 id: id,
                 options: options,
                 name: Fact.Context.via(context, id)
               ]
             ]}
        }
      end

      @doc """
      Starts the indexer process.
      """
      def start_link(opts \\ []) do
        {indexer_opts, start_opts} = Keyword.split(opts, [:context, :id, :options])

        context = Keyword.fetch!(indexer_opts, :context)
        {indexer_mod, indexer_key} = indexer_id = Keyword.fetch!(indexer_opts, :id)
        options = Keyword.get(indexer_opts, :options, []) ++ [indexer_key: indexer_key]

        state = %__MODULE__{
          context: context,
          indexer_id: indexer_id,
          indexer_opts: options,
          checkpoint: 0
        }

        GenServer.start_link(__MODULE__, state, start_opts)
      end

      @impl true
      @doc false
      def init(%{context: context, indexer_id: indexer_id} = state) do
        :ok = Fact.IndexCheckpointFile.ensure_exists(context, indexer_id)
        :ok = Fact.EventPublisher.subscribe(context, :all)
        {:ok, state, {:continue, :rebuild_and_join}}
      end

      @impl true
      @doc false
      def handle_continue(
            :rebuild_and_join,
            %{context: context, indexer_id: indexer_id} = state
          ) do
        checkpoint = rebuild_index(state)
        publish_ready(state, checkpoint)
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
              {:ok, index_result} = append_index(record, state)
              index_result.position

            unindexed <= 0 ->
              checkpoint
          end

        {:noreply, %{state | checkpoint: new_checkpoint}}
      end

      @spec rebuild_index(Fact.EventIndexer.t()) :: Fact.Types.read_position()
      defp rebuild_index(%{context: context, indexer_id: indexer_id} = state) do
        checkpoint = Fact.IndexCheckpointFile.read(context, indexer_id)

        Fact.LedgerFile.read(context, position: checkpoint)
        |> Stream.map(&Fact.RecordFile.read(context, &1))
        |> Enum.reduce(checkpoint, fn record, _acc ->
          {:ok, result} = append_index(record, state)
          result.position
        end)
      end

      @spec append_index(Fact.Types.record(), Fact.EventIndexer.t()) ::
              {:ok, Fact.EventIndexer.index_result()}
      defp append_index(
             {record_id, %{@event_store_position => position} = event} = _record,
             %{
               context: context,
               indexer_id: indexer_id,
               indexer_opts: indexer_opts
             } = state
           ) do
        index_values =
          index_event(event, indexer_opts)
          |> List.wrap()

        Enum.each(index_values, fn index ->
          Fact.IndexFile.write(context, indexer_id, index, record_id)
        end)

        Fact.IndexCheckpointFile.write(context, indexer_id, position)

        index_result = %{
          position: position,
          record_id: record_id,
          index_values: index_values
        }

        publish_indexed(state, index_result)

        {:ok, index_result}
      end

      @spec publish_indexed(Fact.EventIndexer.t(), Fact.EventIndexer.index_result()) ::
              :ok | {:error, term()}
      defp publish_indexed(%{context: context, indexer_id: indexer_id} = state, index_result) do
        Phoenix.PubSub.broadcast(
          Fact.Context.pubsub(context),
          Fact.EventIndexer.topic(indexer_id),
          {:indexed, indexer_id, index_result}
        )
      end
      
      defp publish_ready(%{context: context, indexer_id: indexer_id} = state, checkpoint) do
        Phoenix.PubSub.broadcast(
          Fact.Context.pubsub(context),
          Fact.EventIndexer.topic(indexer_id),
          {:ready, indexer_id, checkpoint}
        )
      end
    end
  end
end
