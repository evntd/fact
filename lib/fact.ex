defmodule Fact do
  @moduledoc """
  Fact provides a lightweight, file system-backed event sourcing database.
  A Fact instance consists of a supervision tree containing the processes
  that manage the read/write access, the ledger, indexing, streams, and queries.

  ## Instances
    
  Multiple Fact instances may be started within the same BEAM node. Each instance
  is identified by an atom (`:instance`), and all internal processes are namespaced
  by that value. This enables applications to run separate logical databases side by
  side for multi-tenant workloads, testing, or isolating contexts.

  The default instance name is `:""`, allowing simple single-instance app usage 
  without requiring explicit naming.
    
  ## Start an Instance
    
  Each Fact instance corresponds to its own supervision tree and its own file system
  backed event store. 
    
  Use `start_link/2` to start a new Fact supervision tree.

      {:ok, pid} = Fact.start_link(:my_instance)
    
  ### Options
    
  - `:instance` - (atom)
    The instance name. This is used to namespace all processes belonging to the instance.
    Defaults to `:""` for applications that only need a single event store.

  - `:path` - (binary)
    Filesystem path where event data is stored. Passed to `Fact.Storage`. If not provided,
    the storage module may choose its own default root.

  - `:driver` - module
    The storage driver to use. Allows customization of how event files are persisted.
    Defaults to `Fact.Storage.Driver.ByEventId`.

  - `:format` - module
    Controls how event files are encoded/decoded. Defaults to `Fact.Storage.Format.Json`.

  - `:indexers` - list of `{module, opts}` tuples. Allows customization of which indexers
    are started for the instance. If not provided, Fact starts a default set of indexers.

      - `Fact.EventStreamIndexer`
      - `Fact.EventTypeIndexer`
      - `Fact.EventTagsIndexer`
      - `Fact.EventDataIndexer`

  ### Process Structure
    
  Starting an instance creates a supervision tree containing:
    
  - Multiple `Registry` processes for event streams, writers, and indexers.  
  - `Fact.Storage` - the file system backed persistence layer.
  - `Fact.EventLedger` - manages appending events, sequencing, and managing event query based consistency boundaries.  
  - `Fact.EventPublisher` - publishes events to subscribers.
  - `Fact.EventIndexerManager` - starts and supervises indexers.
  - `Fact.EventStreamWriterSupervisor` - A `DynamicSupervisor` for managing event streams as consistency boundaries.  

  ## Appending Events
    
  Events can be appended to either:
    
  - an event stream (identified by a string), or  
  - an event query (`Fact.EventQuery`) describing how to select a set of events.  
    
  ## Reading Events  

  Reading returns a `Stream` of `Fact.Type.event` in sequence number order.
    
      Fact.read(:my_instance, "users")
      |> Enum.to_list()

  ## Using `Fact` in your Modules
    
  To bind a module to a specific Fact instance, use:
    
      use Fact, name: :my_instance
    
  This injects convenient instance-scoped wrappers:
    
      - start_link/1
      - append/3
      - read/2
  """

  @default_instance_name :""

  @spec start_link(instance :: atom(), opts :: keyword) :: {:ok, pid()} | {:error, term()}
  def start_link(instance \\ @default_instance_name, opts \\ []) do
    Fact.Supervisor.start_link(Keyword.put(opts, :instance, instance))
  end

  def append(instance, events, boundary, append_opts \\ [])

  def append(instance, events, %Fact.EventQuery{} = query, append_opts),
    do: append(instance, events, [query], append_opts)

  def append(instance, events, [%Fact.EventQuery{}] = query, append_opts),
    do: Fact.EventQueryWriter.append(instance, events, query, append_opts)

  def append(instance, events, event_stream, append_opts) when is_binary(event_stream),
    do: Fact.EventStreamWriter.append(instance, events, event_stream, append_opts)

  def read(instance, event_source, read_opts \\ []) do
    Fact.EventReader.read(instance, event_source, read_opts)
    |> Stream.map(fn {_, record} -> record end)
  end

  defdelegate backup(instance, backup_path), to: Fact.Storage

  defmacro __using__(opts) do
    instance_name = Keyword.get(opts, :name, @default_instance_name)

    quote do
      @instance_name unquote(instance_name)

      def start_link(opts \\ []) do
        Fact.start_link(Keyword.put(opts, :name, @instance_name))
      end

      def append(events, event_stream_or_query, append_opts \\ []) do
        Fact.append(@instance_name, events, event_stream_or_query, append_opts)
      end

      def read(event_source, read_opts \\ []) do
        Fact.read(@instance_name, event_source, read_opts)
      end

      def backup(backup_path) do
        Fact.backup(@instance_name, backup_path)
      end
    end
  end
end
