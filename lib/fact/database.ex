defmodule Fact.Database do
  @moduledoc """
  Represents a running Fact database instance and orchestrates indexing, event tracking, 
  and record publishing.

  `Fact.Database` is a GenServer that maintains state about:
    * The database's ledger position
    * Active indexers and their progress
    * Locks for safe concurrent access
    * The last published position to subscribers

  This module provides:
    * Reading events, indexes, and the ledger
    * Ensuring and starting indexers
    * Tracking indexer progress and publishing indexed positions
    * High-level coordination of database internals via `Fact.Registry` and `Fact.EventPublisher`
  """

  use GenServer

  require Logger

  alias Fact.Event.Schema

  defstruct [
    :chase_pos,
    :database_id,
    :indexers,
    :lock,
    :published_pos
  ]

  @topic "#{__MODULE__}"

  def ensure_indexer(database_id, indexer_module, options \\ []) do
    if function_exported?(indexer_module, :child_spec, 1) do
      child_spec = indexer_module.child_spec(Keyword.put(options, :database_id, database_id))
      GenServer.call(Fact.Registry.via(database_id, __MODULE__), {:ensure_indexer, child_spec})
    else
      {:error, :invalid_indexer_module}
    end
  end

  def last_position(database_id) do
    with stream <-
           Fact.LedgerFile.read(database_id, direction: :backward, position: :end, count: 1),
         event <- Fact.RecordFile.read_event(database_id, stream |> Enum.at(0)) do
      event[Schema.get(database_id).event_store_position]
    end
  end

  defp publish_indexed(database_id, position) do
    Phoenix.PubSub.broadcast(Fact.Registry.pubsub(database_id), @topic, {:indexed, position})
  end

  def read_event(database_id, record_id) do
    Fact.RecordFile.read_event(database_id, record_id)
  end

  def read_index(database_id, indexer_id, index, read_opts) do
    map_read_results = to_result(database_id, read_opts)
    map_read_results.(Fact.IndexFile.read(database_id, indexer_id, index, read_opts))
  end

  def read_ledger(database_id, read_opts) do
    map_read_results = to_result(database_id, read_opts)
    map_read_results.(Fact.LedgerFile.read(database_id, read_opts))
  end

  def read_none(database_id, read_opts) do
    map_read_results = to_result(database_id, read_opts)
    map_read_results.(Stream.concat([]))
  end

  def read_query(database_id, query_fun, read_opts) do
    {maybe_count, read_ledger_opts} = Keyword.split(read_opts, [:count])
    predicate = query_fun.(database_id)

    stream =
      Fact.LedgerFile.read(database_id, read_ledger_opts)
      |> Stream.filter(&predicate.(&1))

    map_read_results = to_result(database_id, read_opts)

    case Keyword.get(maybe_count, :count, :all) do
      :all ->
        map_read_results.(stream)

      n ->
        map_read_results.(Stream.take(stream, n))
    end
  end

  def read_record(database_id, record_id) do
    Fact.RecordFile.read(database_id, record_id)
  end

  defp start_child_indexer(database_id, child_spec) do
    case Supervisor.start_child(Fact.Registry.supervisor(database_id), child_spec) do
      {:ok, child} ->
        {:ok, child}

      {:ok, child, _info} ->
        {:ok, child}

      {:error, {:already_started, child}} ->
        {:ok, {:already_started, child}}

      {:error, _} = error ->
        error
    end
  end

  def start_indexer(database_id, indexer_module, options \\ []) do
    if function_exported?(indexer_module, :child_spec, 1) do
      child_spec = indexer_module.child_spec(Keyword.put(options, :database_id, database_id))
      GenServer.call(Fact.Registry.via(database_id, __MODULE__), {:start_indexer, child_spec})
    else
      {:error, :invalid_indexer_module}
    end
  end

  def start_link(options) do
    {opts, start_opts} = Keyword.split(options, [:database_id])

    case Keyword.get(opts, :database_id) do
      nil ->
        {:error, :database_context_required}

      database_id ->
        GenServer.start_link(__MODULE__, database_id, start_opts)
    end
  end

  def subscribe(database_id) do
    Phoenix.PubSub.subscribe(Fact.Registry.pubsub(database_id), @topic)
  end

  defp to_result(database_id, options) do
    shape =
      case Keyword.get(options, :result, :event) do
        :event ->
          &Stream.map(&1, fn record_id ->
            elem(Fact.RecordFile.read(database_id, record_id), 1)
          end)

        :record ->
          &Stream.map(&1, fn record_id -> Fact.RecordFile.read(database_id, record_id) end)

        :record_id ->
          & &1
      end

    if Keyword.get(options, :eager, false),
      do: fn stream -> shape.(stream) |> Enum.to_list() end,
      else: shape
  end

  @impl true
  def handle_call(
        {:ensure_indexer, child_spec},
        from,
        %__MODULE__{database_id: database_id, indexers: indexers} = state
      ) do
    case Map.get(indexers, child_spec.id) do
      # Not started (or not yet observed)
      nil ->
        case start_child_indexer(database_id, child_spec) do
          {:ok, child} when is_pid(child) ->
            new_indexers =
              Map.put(state.indexers, child_spec.id, %{
                pid: child,
                status: :starting,
                waiters: MapSet.new([from]),
                position: 0
              })

            # Danger town! A GenServer call should typically respond, so the caller
            # isn't blocked, receives a timeout, and crashes. But that is exactly what 
            # I want to have happen here. The intent is to have the indexer module 
            # which was just started, to send a :indexer_ready message once it done
            # "catching up" and then we'll respond to all the calling processes.
            {:noreply, %__MODULE__{state | indexers: new_indexers}}

          {:ok, {:already_started, _child}} ->
            # Reality wins. The indexer exists, but wasn't observed yet.
            {:reply, {:ok, child_spec.id}, state}

          {:error, _} = error ->
            {:reply, error, state}
        end

      %{status: status, waiters: waiters} = info when status in [:starting, :started] ->
        new_indexers =
          Map.put(state.indexers, child_spec.id, %{info | waiters: MapSet.put(waiters, from)})

        {:noreply, %__MODULE__{state | indexers: new_indexers}}

      %{status: :ready} ->
        {:reply, {:ok, child_spec.id}, state}
    end
  end

  @impl true
  def handle_call(
        {:start_indexer, child_spec},
        _from,
        %__MODULE__{database_id: database_id} = state
      ) do
    result =
      case start_child_indexer(database_id, child_spec) do
        {:ok, _} ->
          :ok

        {:error, _} = error ->
          error
      end

    {:reply, result, state}
  end

  @impl true
  def handle_cast(
        {:indexer_ready, indexer_id, checkpoint},
        %__MODULE__{database_id: database_id} = state
      ) do
    # start listening for :indexed messages
    Fact.EventIndexer.subscribe(database_id, indexer_id)

    # update the books and extract waiters in a single pass
    {waiters, indexers} =
      Map.get_and_update!(state.indexers, indexer_id, fn info ->
        waiters = Map.get(info, :waiters, MapSet.new())
        {waiters, %{info | status: :ready, position: checkpoint, waiters: MapSet.new()}}
      end)

    # reply to all the waiters who are blocked 
    Enum.each(waiters, &GenServer.reply(&1, {:ok, indexer_id}))

    {:noreply, %__MODULE__{state | indexers: indexers}}
  end

  @impl true
  def handle_cast({:indexer_starting, indexer_id, pid}, %__MODULE__{indexers: indexers} = state) do
    indexer_info =
      Map.get(indexers, indexer_id, %{
        pid: pid,
        status: :starting,
        waiters: MapSet.new(),
        position: 0
      })

    new_indexers =
      Map.put(indexers, indexer_id, %{indexer_info | pid: pid, status: :starting})

    {:noreply, %{state | indexers: new_indexers}}
  end

  @impl true
  def handle_cast(
        {:start_child_indexer, child_spec},
        %__MODULE__{database_id: database_id} = state
      ) do
    Supervisor.start_child(Fact.Registry.supervisor(database_id), child_spec)
    {:noreply, state}
  end

  @impl true
  def handle_info(
        {:appended, {_, event}},
        %__MODULE__{database_id: database_id, chase_pos: chase_pos} = state
      ) do
    pos = event[Schema.get(database_id).event_store_position]

    if pos > chase_pos do
      {:noreply, %{state | chase_pos: pos}}
    else
      Logger.warning(
        "[#{__MODULE__}] handle :appended received event at #{pos}, but high water mark is #{chase_pos}"
      )

      {:noreply, state}
    end
  end

  @impl true
  def handle_info(
        {:indexed, indexer, %{position: pos}},
        %{database_id: database_id, indexers: indexers, published_pos: published_pos} = state
      ) do
    {_, new_indexers} =
      Map.get_and_update(indexers, indexer, fn %{position: cur_pos} = info ->
        new_pos = max(cur_pos, pos)
        {new_pos, %{info | position: new_pos}}
      end)

    min_pos = Enum.map(new_indexers, fn {_, %{position: p}} -> p end) |> Enum.min()

    if min_pos > published_pos do
      publish_indexed(database_id, min_pos)
      {:noreply, %{state | indexers: new_indexers, published_pos: min_pos}}
    else
      {:noreply, %{state | indexers: new_indexers}}
    end
  end

  @impl true
  def init(database_id) do
    case Fact.Lock.acquire(database_id, :run) do
      {:ok, lock} ->
        last_pos = last_position(database_id)

        state = %__MODULE__{
          chase_pos: last_pos,
          database_id: database_id,
          indexers: %{},
          lock: lock,
          published_pos: last_pos
        }

        Fact.EventPublisher.subscribe(database_id, :all)

        {:ok, state}

      {:error, {:locked, lock_info}} ->
        {:stop, {:locked, lock_info}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def terminate(_reason, %{database_id: database_id, lock: lock}) do
    Fact.Lock.release(database_id, lock)
    :ok
  end
end
