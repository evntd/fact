defmodule Fact.RecordCache do
  @moduledoc """
  An in-memory LFU (Least Frequently Used) cache for decoded event records.

  Since event records are immutable once written, they can be cached indefinitely without
  concern for invalidation. This cache avoids repeated disk reads and JSON deserialization
  for frequently accessed records.

  The cache uses two ETS tables per database instance:

    * A **data table** (`:set`, `:public`, `read_concurrency: true`) for O(1) lookups from
      any process without going through the GenServer
    * A **frequency table** (`:ordered_set`, `:private`) for LFU eviction, sorted by
      `{frequency, record_id}`

  Cache reads bypass the GenServer entirely via direct ETS access. Frequency bumps and
  inserts are sent as casts to avoid blocking the caller.

  To prevent stale entries from monopolizing the cache, a periodic **frequency decay** sweep
  halves all frequency counters at a configurable interval (default: 10 minutes). Entries
  whose frequency decays to zero are evicted. This ensures that records which were hot in
  the past but are no longer accessed gradually lose their position to actively read records.

  The cache is **disabled by default** and only started when a `:max_size` is configured
  via `Fact.open/2`:

      {:ok, db} = Fact.open("data/my_database", cache: [max_size: 512 * 1024 * 1024])

  When no cache process is registered for a database, `get/2` returns `:miss` and `put/3`
  is a no-op, adding only a fast registry lookup to the read path.

  This process is started and supervised by `Fact.DatabaseSupervisor`.
  """
  @moduledoc since: "0.3.0"
  use GenServer

  @typedoc """
  Cache configuration options.

    * `:max_size` - Maximum cache size in bytes. Required to enable the cache.
    * `:decay_interval` - Time in milliseconds between frequency decay sweeps. Defaults to `600_000` (10 minutes). All frequency counters are halved on each sweep, preventing stale entries from monopolizing the cache indefinitely.
  """
  @typedoc since: "0.3.0"
  @type cache_option ::
          {:max_size, pos_integer()}
          | {:decay_interval, pos_integer()}

  @typedoc """
  Options accepted by `start_link/1`.

    * `:database_id` - (required) The database identifier.
    * `:name` - (required) The registered process name, typically constructed via `Fact.Registry.via/2`.
    * `:max_size` - (required) Maximum cache size in bytes.
    * `:decay_interval` - See `t:cache_option/0`.
  """
  @typedoc since: "0.3.0"
  @type option ::
          {:database_id, Fact.database_id()}
          | {:name, GenServer.name()}
          | {:max_size, pos_integer()}
          | {:decay_interval, pos_integer()}

  # -----------------------------
  # Public API
  # -----------------------------

  @doc """
  Starts a `Fact.RecordCache` process linked to the calling process.
  """
  @doc since: "0.3.0"
  @spec start_link([option()]) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  @doc """
  Looks up a cached event record.

  Performs a direct ETS read without going through the GenServer. On a cache hit, a frequency
  bump is cast to the GenServer asynchronously.

  Returns `{:ok, {record_id, event_map}}` on hit, or `:miss` when the record is not cached
  or the cache is disabled for this database.
  """
  @doc since: "0.3.0"
  @spec get(Fact.database_id(), Fact.record_id()) :: {:ok, Fact.record()} | :miss
  def get(database_id, record_id) do
    table = data_table_name(database_id)

    case :ets.whereis(table) do
      :undefined ->
        :miss

      _ref ->
        case :ets.lookup(table, record_id) do
          [{^record_id, event_map, _size, _freq}] ->
            GenServer.cast(Fact.Registry.via(database_id, __MODULE__), {:bump, record_id})
            {:ok, {record_id, event_map}}

          [] ->
            :miss
        end
    end
  end

  @doc """
  Caches a decoded event record.

  The insert is performed asynchronously via a cast to the GenServer. If the cache is
  disabled for this database, this is a no-op.
  """
  @doc since: "0.3.0"
  @spec put(Fact.database_id(), Fact.record_id(), Fact.event_record()) :: :ok
  def put(database_id, record_id, event_map) do
    GenServer.cast(Fact.Registry.via(database_id, __MODULE__), {:put, record_id, event_map})
  end

  # -----------------------------
  # Inspection & Management
  # -----------------------------

  @typedoc """
  Cache size information returned by `size/1`.

    * `:current` - Current cache usage in bytes.
    * `:max` - Maximum configured cache size in bytes.
    * `:percentage` - Current usage as a percentage of max capacity (`0.0` to `100.0`).
  """
  @typedoc since: "0.3.0"
  @type size_info :: %{
          current: non_neg_integer(),
          max: pos_integer(),
          percentage: float()
        }

  @doc """
  Returns the current cache size, maximum capacity, and usage percentage.

  Returns `{:error, :not_enabled}` when the cache is not active for the given database.
  """
  @doc since: "0.3.0"
  @spec size(Fact.database_id()) :: {:ok, size_info()} | {:error, :not_enabled}
  def size(database_id) do
    with_cache(database_id, fn -> GenServer.call(via(database_id), :size) end)
  end

  @doc """
  Returns the number of records currently in the cache.

  Performs a direct ETS read without going through the GenServer.

  Returns `{:error, :not_enabled}` when the cache is not active for the given database.
  """
  @doc since: "0.3.0"
  @spec count(Fact.database_id()) :: {:ok, non_neg_integer()} | {:error, :not_enabled}
  def count(database_id) do
    table = data_table_name(database_id)

    case :ets.whereis(table) do
      :undefined -> {:error, :not_enabled}
      _ref -> {:ok, :ets.info(table, :size)}
    end
  end

  @doc """
  Removes all entries from the cache.

  Returns `{:error, :not_enabled}` when the cache is not active for the given database.
  """
  @doc since: "0.3.0"
  @spec clear(Fact.database_id()) :: :ok | {:error, :not_enabled}
  def clear(database_id) do
    with_cache(database_id, fn -> GenServer.call(via(database_id), :clear) end)
  end

  @doc """
  Returns the top `n` most frequently accessed cached records.

  Each entry is a `{record_id, frequency}` tuple, sorted by frequency in descending order.

  Returns `{:error, :not_enabled}` when the cache is not active for the given database.
  """
  @doc since: "0.3.0"
  @spec top(Fact.database_id(), pos_integer()) ::
          {:ok, [{Fact.record_id(), non_neg_integer()}]} | {:error, :not_enabled}
  def top(database_id, n) when is_integer(n) and n > 0 do
    with_cache(database_id, fn -> GenServer.call(via(database_id), {:top, n}) end)
  end

  defp via(database_id), do: Fact.Registry.via(database_id, __MODULE__)

  defp with_cache(database_id, fun) do
    case :ets.whereis(data_table_name(database_id)) do
      :undefined -> {:error, :not_enabled}
      _ref -> fun.()
    end
  end

  # -----------------------------
  # GenServer Callbacks
  # -----------------------------

  @default_decay_interval 600_000

  @impl true
  def init(opts) do
    database_id = Keyword.fetch!(opts, :database_id)
    max_size = Keyword.fetch!(opts, :max_size)
    decay_interval = Keyword.get(opts, :decay_interval, @default_decay_interval)

    data_table =
      :ets.new(data_table_name(database_id), [
        :set,
        :public,
        :named_table,
        read_concurrency: true
      ])

    freq_table =
      :ets.new(freq_table_name(database_id), [
        :ordered_set,
        :private,
        :named_table
      ])

    Process.send_after(self(), :decay, decay_interval)

    {:ok,
     %{
       database_id: database_id,
       max_size: max_size,
       current_size: 0,
       data_table: data_table,
       freq_table: freq_table,
       decay_interval: decay_interval
     }}
  end

  @impl true
  def handle_cast({:put, record_id, event_map}, state) do
    case :ets.lookup(state.data_table, record_id) do
      [{^record_id, _, _, _}] ->
        {:noreply, state}

      [] ->
        byte_size = :erlang.external_size(event_map)
        state = evict_until_fits(state, byte_size)

        if byte_size <= state.max_size do
          :ets.insert(state.data_table, {record_id, event_map, byte_size, 1})
          :ets.insert(state.freq_table, {{1, record_id}})
          {:noreply, %{state | current_size: state.current_size + byte_size}}
        else
          {:noreply, state}
        end
    end
  end

  def handle_cast({:bump, record_id}, state) do
    case :ets.lookup(state.data_table, record_id) do
      [{^record_id, event_map, byte_size, old_freq}] ->
        :ets.delete(state.freq_table, {old_freq, record_id})
        new_freq = old_freq + 1
        :ets.insert(state.data_table, {record_id, event_map, byte_size, new_freq})
        :ets.insert(state.freq_table, {{new_freq, record_id}})
        {:noreply, state}

      [] ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_call(:size, _from, state) do
    percentage =
      if state.max_size > 0,
        do: Float.round(state.current_size / state.max_size * 100, 2),
        else: 0.0

    info = %{current: state.current_size, max: state.max_size, percentage: percentage}
    {:reply, {:ok, info}, state}
  end

  def handle_call(:clear, _from, state) do
    :ets.delete_all_objects(state.data_table)
    :ets.delete_all_objects(state.freq_table)
    {:reply, :ok, %{state | current_size: 0}}
  end

  def handle_call({:top, n}, _from, state) do
    entries = collect_top(state.freq_table, :ets.last(state.freq_table), n, [])
    {:reply, {:ok, entries}, state}
  end

  # -----------------------------
  # Frequency Decay
  # -----------------------------

  @impl true
  def handle_info(:decay, state) do
    evicted_bytes = decay_frequencies(state)
    Process.send_after(self(), :decay, state.decay_interval)
    {:noreply, %{state | current_size: state.current_size - evicted_bytes}}
  end

  defp decay_frequencies(state) do
    :ets.foldl(
      fn {record_id, event_map, byte_size, freq}, evicted_bytes ->
        new_freq = div(freq, 2)

        if new_freq == 0 do
          :ets.delete(state.freq_table, {freq, record_id})
          :ets.delete(state.data_table, record_id)
          evicted_bytes + byte_size
        else
          :ets.delete(state.freq_table, {freq, record_id})
          :ets.insert(state.data_table, {record_id, event_map, byte_size, new_freq})
          :ets.insert(state.freq_table, {{new_freq, record_id}})
          evicted_bytes
        end
      end,
      0,
      state.data_table
    )
  end

  # -----------------------------
  # Eviction
  # -----------------------------

  defp evict_until_fits(state, needed) do
    if state.current_size + needed <= state.max_size do
      state
    else
      case :ets.first(state.freq_table) do
        :"$end_of_table" ->
          state

        {_freq, record_id} = key ->
          [{^record_id, _event_map, byte_size, _freq}] =
            :ets.lookup(state.data_table, record_id)

          :ets.delete(state.freq_table, key)
          :ets.delete(state.data_table, record_id)
          evict_until_fits(%{state | current_size: state.current_size - byte_size}, needed)
      end
    end
  end

  # -----------------------------
  # Helpers
  # -----------------------------

  defp collect_top(_table, :"$end_of_table", _remaining, acc), do: acc
  defp collect_top(_table, _key, 0, acc), do: acc

  defp collect_top(table, {freq, record_id} = key, remaining, acc) do
    collect_top(table, :ets.prev(table, key), remaining - 1, acc ++ [{record_id, freq}])
  end

  defp data_table_name(database_id) do
    :"fact_record_cache_data_#{database_id}"
  end

  defp freq_table_name(database_id) do
    :"fact_record_cache_freq_#{database_id}"
  end
end
