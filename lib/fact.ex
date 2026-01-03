defmodule Fact do
  @moduledoc """
  Fact provides a lightweight, event sourcing database backed by the file system.

  An instance consists of a supervision tree containing the processes that manage reads and writes to ledger, 
  indexing, streams, and queries. Multiple instances may be started within the same BEAM node. Each instance is
  identified by a `Fact.Instance` structure. 
      
  ## Start an Instance
    
  Use `open/1` to start a Fact supervision tree and receive the `Fact.Instance` that provides a handle for accessing
  the database. 

      {:ok, instance } = Fact.open("/var/lib/fact-db")

  ### Process Structure
    
  Starting an instance creates a supervision tree containing:
    
  - `Fact.Registry` - processes for event streams, writers, and indexers.  
  - `Fact.Storage` - the file system backed persistence layer.
  - `Fact.EventLedger` - manages appending events, sequencing, and managing event query based consistency boundaries.  
  - `Fact.EventPublisher` - publishes events to subscribers.
  - `Fact.EventIndexerManager` - starts and supervises indexers.
  - `Fact.EventStreamWriterSupervisor` - A `DynamicSupervisor` for managing event streams as consistency boundaries.  

  ## Appending Events
    
  Events can be appended via streams or query conditions.  
    
  ## Reading Events  

  Events can be read from the ledger, streams, queries, or any index.

  ## Using `Fact` in your Modules
    
  To bind a module to a specific Fact instance, use:
    
      use Fact, name: :my_instance
    
  """

  def open(path) do
    {:ok, _pid} =
      case Process.whereis(Fact.SystemSupervisor) do
        nil ->
          Fact.SystemSupervisor.start_link([])

        pid ->
          {:ok, pid}
      end

    Fact.SystemSupervisor.start_database(path)
  end

  @spec append(
          Fact.Context.t(),
          Fact.Types.event() | [Fact.Types.event(), ...],
          Fact.Query.t(),
          Fact.Types.event_position(),
          keyword()
        ) :: {:ok, Fact.Types.event_position()} | {:error, term()}
  def append(
        %Fact.Context{} = context,
        events,
        fail_if_match \\ nil,
        after_position \\ 0,
        opts \\ []
      ) do
    Fact.EventLedger.commit(context, events, fail_if_match, after_position, opts)
  end

  @doc """
  Appends one or more events to a stream. This enriches the appended event records with 
  `stream_id` and `stream_position`.

  * `events` is a single event or list of events. 
  * `event_stream` is a string that uniquely identifies stream.
  * `event_position` is a non-negative integer which is used to ensure you can only append 
    to the stream if it is at the exact `stream_position`. 

    You may also provide one of the following values for different behavior.
      * `:any` - No check is made, any  
      * `:none` - Ensures the stream does not exist, this is the first append. Same as expected_position = 0.
      * `:exists` - Ensures the stream already exists, equivalent to expected_position >= 1.

  ## Examples
    
  Append a single event.
    
      iex> Fact.start_link(:mydb)
      {:ok, #PID<0.200.0>}
    
      iex> Fact.append_stream(:mydb, %{type: "MyFirstEvent"}, "myteststream")
      {:ok, 1}
    
      iex> Fact.read(:mydb, "myteststream") |> Enum.to_list()
      [
        %{
          "event_data" => %{},
          "event_id" => "13b92de902c44763aaffd5df6d42036e",                                                                                                                                                                                                                                                               
          "event_metadata" => %{},                                                                                                                                                                                                                                                                                        
          "event_tags" => [],                                                                                                                                                                                                                                                                                             
          "event_type" => "MyTestEvent",                                                                                                                                                                                                                                                                                  
          "store_position" => 1,                                                                                                                                                                                                                                                                                          
          "store_timestamp" => 1765434877444299,                                                                                                                                                                                                                                                                          
          "stream_id" => "myteststream",                                                                                                                                                                                                                                                                                  
          "stream_position" => 1                                                                                                                                                                                                                                                                                          
        }                                                                                                                                                                                                                                                                                                                 
      ]  

  Append another event, expecting correct stream position.
    
      iex> Fact.append_stream(:mydb, %{type: "MySecondEvent"}, "myteststream", 1)
      {:ok, 2}
    
  Append a third event, supplying an incorrect stream position.
    
      iex> Fact.append_stream(:mydb, %{type: "MyThirdEvent"}, "myteststream", 1)
      {:error, %Fact.ConcurrencyError{source: "myteststream", actual: 2, expected: 1}}

  """
  @spec append_stream(
          Fact.Context.t(),
          Fact.Types.event() | [Fact.Types.event(), ...],
          Fact.Types.event_stream(),
          Fact.Types.event_position() | :any | :none | :exists,
          keyword()
        ) :: {:ok, Fact.Types.event_position()} | {:error, term()}
  def append_stream(
        %Fact.Context{} = context,
        events,
        event_stream,
        expected_position \\ :any,
        opts \\ []
      ) do
    Fact.EventStreamWriter.commit(context, events, event_stream, expected_position, opts)
  end

  @doc """
  Read events from the event store in a variety of different ways.

    * `:all` — reads from the global ledger index in event-store order.
    * an event stream — reads events belonging to a specific stream.
    * one or more `%Fact.EventQuery{}` structs — executes the query engine and streams results.

  All read operations return a lazy `Stream` of `{record_id, event_record}` tuples, allowing callers
  to process large event sets efficiently without loading them fully into memory.

  ## Options

  The following options are accepted for all read strategies:
    
    * `:direction` — traversal direction (default: `:forward`)
      * `:forward` — increasing positions
      * `:backward` — decreasing positions

    * `:position` - The position to begin reading relative to the event source.
      * `:start` - begin at the start position.
      * `:end` - begin at the last position.
      * integer - starting position, when reading `:forward` this is exclusive, when reading `:backward`
        it is inclusive.


    * `:count` — maximum number of events to return (default: all)
      * `:all` - read all the events
      * integer - a non-negative value

  The reader validates these options and raises a `Fact.DatabaseError` on invalid values.
  """
  @spec read(Fact.Context.t(), Fact.Types.read_event_source(), Fact.Types.read_options()) ::
          Enumerable.t(Fact.Types.event_record())
  def read(context, event_source, opts \\ [])

  def read(_context, :none, _read_opts), do: Stream.concat([])

  def read(context, :all, read_opts) do
    Fact.LedgerFile.read(context, read_opts)
  end

  def read(context, {:stream, event_stream}, read_opts) when is_binary(event_stream) do
    Fact.IndexFile.read(context, {Fact.EventStreamIndexer, nil}, event_stream, read_opts)
  end

  def read(context, {:query, :all}, read_opts) do
    read(context, :all, read_opts)
  end

  def read(context, {:query, :none}, read_opts) do
    read(context, :none, read_opts)
  end

  def read(context, {:query, %Fact.QueryItem{} = query}, read_opts) do
    read(context, {:query, Fact.QueryItem.to_function(query)}, read_opts)
  end

  def read(context, {:query, [%Fact.QueryItem{} | _] = query_items}, read_opts) do
    read(context, {:query, Fact.QueryItem.to_function(query_items)}, read_opts)
  end

  def read(_context, {:query, query_fun}, _read_opts) when is_function(query_fun) do
    #Fact.Storage.read_query(context, query_fun, read_opts)
    :ok
  end

  def read(context, {:index, indexer_mod, index}, read_opts) do
    Fact.IndexFile.read(context, indexer_mod, index, read_opts)
  end
end
