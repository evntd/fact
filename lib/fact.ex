defmodule Fact do
  @moduledoc """
  Fact is an event sourcing database, an event store.
  """

  def open(path) do
    {:ok, _pid} =
      case Process.whereis(Fact.Supervisor) do
        nil ->
          Fact.Supervisor.start_link([])

        pid ->
          {:ok, pid}
      end

    Fact.Supervisor.start_database(path)
  end

  @spec append(
          Fact.Types.database_id(),
          Fact.Types.event() | [Fact.Types.event(), ...],
          Fact.Query.t(),
          Fact.Types.event_position(),
          keyword()
        ) :: {:ok, Fact.Types.event_position()} | {:error, term()}
  def append(
        database_id,
        events,
        fail_if_match \\ nil,
        after_position \\ 0,
        opts \\ []
      ) do
    Fact.EventLedger.commit(database_id, events, fail_if_match, after_position, opts)
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
    
      iex> {:ok, db} = Fact.open("data/turtle")
      {:ok, "TURTLE4F7Q6Y2X3VQKBJ5M7P4Z"}
    
      iex> Fact.append_stream(db, %{type: "egg_hatched", data: %{name: "Turts"}}, "turtle-1")
      {:ok, 1}
    
      iex> Fact.read(db, {:stream, "turtle-1"}) |> Enum.to_list()
      [
        %{
          "event_data" => %{"name" => "Turts"},
          "event_id" => "3bb4808303c847fd9ceb0a1251ef95da",                                                                                                                                                                                                                                                               
          "event_metadata" => %{},                                                                                                                                                                                                                                                                                        
          "event_tags" => [],                                                                                                                                                                                                                                                                                             
          "event_type" => "egg_hatched",                                                                                                                                                                                                                                                                                  
          "store_position" => 2,                                                                                                                                                                                                                                                                                          
          "store_timestamp" => 1765039106962264,                                                                                                                                                                                                                                                                          
          "stream_id" => "turtle-1",                                                                                                                                                                                                                                                                                  
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
          Fact.Types.database_id(),
          Fact.Types.event() | [Fact.Types.event(), ...],
          Fact.Types.event_stream(),
          Fact.Types.event_position() | :any | :none | :exists,
          keyword()
        ) :: {:ok, Fact.Types.event_position()} | {:error, term()}
  def append_stream(
        database_id,
        events,
        event_stream,
        expected_position \\ :any,
        opts \\ []
      ) do
    Fact.EventStreamWriter.commit(database_id, events, event_stream, expected_position, opts)
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
  @spec read(Fact.Types.database_id(), Fact.Types.read_event_source(), Fact.Types.read_options()) ::
          Enumerable.t(Fact.Types.event_record())
  def read(database_id, event_source, opts \\ [])

  def read(_context, :none, _read_opts), do: Stream.concat([])

  def read(database_id, :all, read_opts) do
    Fact.Database.read_ledger(database_id, read_opts)
  end

  def read(database_id, {:stream, event_stream}, read_opts) when is_binary(event_stream) do
    read(database_id, {:index, {Fact.EventStreamIndexer, nil}, event_stream}, read_opts)
  end

  def read(database_id, {:query, :all}, read_opts) do
    read(database_id, :all, read_opts)
  end

  def read(database_id, {:query, :none}, read_opts) do
    read(database_id, :none, read_opts)
  end

  def read(database_id, {:query, %Fact.QueryItem{} = query}, read_opts) do
    read(database_id, {:query, Fact.QueryItem.to_function(query)}, read_opts)
  end

  def read(database_id, {:query, [%Fact.QueryItem{} | _] = query_items}, read_opts) do
    read(database_id, {:query, Fact.QueryItem.to_function(query_items)}, read_opts)
  end

  def read(database_id, {:query, query_fun}, read_opts) when is_function(query_fun) do
    Fact.Database.read_query(database_id, query_fun, read_opts)
  end

  def read(database_id, {:index, indexer_id, index}, read_opts) do
    Fact.Database.read_index(database_id, indexer_id, index, read_opts)
  end
end
