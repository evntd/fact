# Record Cache

The **Record Cache** is an optional, in-memory cache for decoded event records. It eliminates
repeated disk reads and JSON deserialization for frequently accessed records, significantly
improving read throughput for hot data.

At a high level:

- Event records are **immutable** once written, so cache invalidation is never needed
- The cache uses **LFU (Least Frequently Used)** eviction to retain the most accessed records
- Periodic **frequency decay** prevents stale entries from monopolizing the cache
- Reads bypass the GenServer entirely via **direct ETS access** for minimal latency overhead
- The cache is **disabled by default** and only activated when a `:max_size` is configured

## Why Cache Event Records?

Every time an event record is read through `Fact.RecordFile.read/2`, the system performs two
operations:

1. **Disk I/O** &mdash; reading the event record file from the filesystem
2. **Deserialization** &mdash; decoding the JSON binary into an Elixir map

For workloads that repeatedly access the same events &mdash; such as queries over consistency
boundaries, stream head lookups, or subscription replays &mdash; these operations are redundant.
The record on disk has not changed and never will.

The Record Cache sits inside `RecordFile.read/2` and intercepts reads before they reach the
filesystem. On a cache hit, the decoded event map is returned directly from memory. On a miss,
the record is read from disk and deserialized as usual, then stored in the cache for subsequent
reads.

## Eviction Strategy

The cache uses **Least Frequently Used (LFU)** eviction. Each cached record tracks how many
times it has been accessed. When the cache reaches its configured size limit and a new record
needs to be inserted, the records with the lowest access frequency are evicted first.

LFU is well-suited for event stores because:

- **Hot records stay cached** &mdash; genesis events, stream heads, and frequently queried events
  naturally accumulate high access counts and are retained
- **Immutability eliminates staleness** &mdash; unlike mutable data where LFU can pin stale entries,
  event records never change, so a high frequency count always reflects genuine value
- **Read patterns are non-uniform** &mdash; a small subset of events typically accounts for the
  majority of reads, and LFU directly optimizes for this distribution

## Frequency Decay

A classic problem with LFU caches is **frequency pollution**: a record that was heavily read in
the past accumulates a high frequency count and remains cached indefinitely, even after it becomes
completely cold. New records that are actively read cannot accumulate enough frequency to displace
the stale entry.

The Record Cache solves this with periodic **frequency decay**. At a configurable interval
(default: 10 minutes), the GenServer sweeps all cached entries and halves their frequency counters.
This has two effects:

1. **Stale entries lose their advantage** &mdash; a record that was read 10,000 times last week but
   is no longer accessed will see its frequency halved on each sweep: 10,000 &rarr; 5,000 &rarr;
   2,500 &rarr; 1,250, and so on. Within a few decay cycles, actively read records overtake it.

2. **Cold entries are evicted** &mdash; when an entry's frequency decays to zero (i.e., it had a
   frequency of 1 and was halved), it is removed from the cache entirely. This provides a natural
   cleanup mechanism for records that are no longer relevant.

The decay interval is tunable. A shorter interval causes frequencies to decay faster, making the
cache more responsive to changing access patterns. A longer interval preserves frequency history
for longer, favoring stability over responsiveness.

## Architecture

The cache is implemented as a `Fact.RecordCache` GenServer, one per database instance, supervised
by `Fact.DatabaseSupervisor`. It uses two ETS tables:

### Data Table

A `:set` table with `:public` access and `read_concurrency: true`. Each entry stores:

- The record ID (key)
- The decoded event map
- The approximate byte size of the entry
- The access frequency counter

Because the table is public, any process can perform a direct `:ets.lookup/2` without sending a
message to the GenServer. This keeps cache reads off the GenServer's mailbox entirely, preventing
it from becoming a bottleneck under high read concurrency.

### Frequency Table

An `:ordered_set` table with `:private` access, keyed by `{frequency, record_id}`. This provides
O(log n) access to the least frequently used entry via `:ets.first/1`, which is used during
eviction.

Only the GenServer interacts with this table. Frequency bumps and inserts are sent as asynchronous
casts, so callers never block on eviction or bookkeeping.

## How It Works

### Cache Hit

1. `RecordFile.read/2` calls `RecordCache.get/2`
2. `get/2` checks if the data ETS table exists (disabled check)
3. Direct `:ets.lookup/2` on the data table
4. On hit: casts a frequency bump to the GenServer and returns the cached record
5. The GenServer updates the frequency counter in both tables asynchronously

### Cache Miss

1. `RecordCache.get/2` returns `:miss`
2. `RecordFile.read/2` reads from disk and deserializes as normal
3. The decoded record is passed to `RecordCache.put/3`
4. `put/3` casts to the GenServer, which computes the byte size, evicts if necessary, and inserts

### Eviction

When a new record would exceed `:max_size`:

1. The GenServer reads the first entry from the frequency table (lowest frequency)
2. Looks up the corresponding byte size from the data table
3. Deletes the entry from both tables and subtracts from the current size
4. Repeats until there is room for the new entry

Records that are larger than `:max_size` are never cached.

## Configuration

The cache is configured through `Fact.open/2` via the `:cache` key:

```elixir
{:ok, db} = Fact.open("data/my_database", cache: [
  max_size: 512 * 1024 * 1024
])
```

With a custom decay interval:

```elixir
{:ok, db} = Fact.open("data/my_database", cache: [
  max_size: 512 * 1024 * 1024,
  decay_interval: 300_000
])
```

| Option            | Type            | Default    | Description                                       |
|-------------------|-----------------|------------|---------------------------------------------------|
| `:max_size`       | `pos_integer()` | disabled   | Maximum cache size in bytes. Required to enable    |
| `:decay_interval` | `pos_integer()` | `600_000`  | Milliseconds between frequency decay sweeps (10 min) |

When `:max_size` is not provided, no cache process is started. The only overhead on the read path
is a single `:ets.whereis/1` call that returns `:undefined`, which is negligible.

### Sizing Guidance

The `:max_size` value represents the approximate total size of cached event maps, measured using
`:erlang.external_size/1`. This is the Erlang external term format size, which is a reasonable
proxy for in-memory size but not an exact match. Actual BEAM memory usage may be slightly higher.

As a starting point:

- **Small workloads** (thousands of events) &mdash; `64 * 1024 * 1024` (64 MiB) may cache the
  entire dataset
- **Medium workloads** (hundreds of thousands of events) &mdash; `256 * 1024 * 1024` (256 MiB)
  keeps the hot set in memory
- **Large workloads** (millions of events) &mdash; `512 * 1024 * 1024` (512 MiB) or more,
  depending on available system memory

The optimal size depends on your read patterns. If a small number of events account for the
majority of reads (common in event-sourced systems), even a modest cache can yield significant
improvements.

## Behavior on Restart

If the `Fact.RecordCache` process crashes, its ETS tables are destroyed (they are owned by the
process). The supervisor restarts the process with an empty cache. This is by design &mdash;
correctness is never affected, only performance temporarily degrades while the cache warms back up.

## Supervision

The `Fact.RecordCache` process is started and supervised by `Fact.DatabaseSupervisor` as part of
each database's supervision tree. It is registered via `Fact.Registry` under the database's scoped
namespace, ensuring full isolation between multiple database instances.

See the [Process Model](../introduction/process-model.md) guide for an overview of the full
supervision tree.
