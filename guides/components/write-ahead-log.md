# Write-Ahead Log

The **Write-Ahead Log (WAL)** is Fact's durability mechanism. Every event is recorded in the WAL
before it is committed to the ledger and indexes. If the system crashes mid-write, the WAL provides
the information needed to recover to a consistent state on the next startup.

At a high level:

- Every event write is appended to the WAL **before** it reaches the ledger or any index
- On crash recovery, `Fact.EventLedger` replays uncommitted WAL entries to restore consistency
- The WAL is organized as a series of numbered **segment files** that rotate automatically
- **Checkpoint entries** mark known-good recovery points, allowing replay to skip already-committed data

This design ensures that no acknowledged write is ever silently lost, even in the face of unexpected
process or system failure.

## Why a Write-Ahead Log?

Fact persists events to multiple locations: a ledger file, one or more index files, and individual
event record files. These writes are not atomic. If the system crashes after writing the event record
but before updating the ledger, the database would be left in an inconsistent state.

The WAL solves this by providing a single, sequential point of truth for in-flight writes:

1. The event is serialized and appended to the WAL
2. The event is written to its record file, the ledger, and the indexes
3. A checkpoint is written to the WAL, marking that all downstream writes completed

If a crash occurs between steps 1 and 3, the recovery process detects the missing checkpoint and
replays the uncommitted entries.

## Segments and Rotation

The WAL is stored as a series of numbered segment files inside the database's WAL directory. Each
segment is an append-only binary file. When the active segment grows beyond the configured
`:max_file_size`, it is closed and a new segment with the next index is opened.

To prevent unbounded disk usage, the WAL enforces a `:max_segments` limit. When a rotation would
exceed this limit, the oldest segment is deleted. Because checkpoints mark the boundary of committed
data, old segments contain only already-committed entries and are safe to remove.

The segment layout on disk looks like this:

```
<database_path>/wal/
  0
  1
  2
  3
```

Each file is named by its integer segment index.

## Entries and Checksums

Every WAL entry (`Fact.WriteAheadLog.Entry`) contains:

- **LSN** (Log Sequence Number) &mdash; a monotonically increasing sequence number
- **Data** &mdash; the serialized binary payload
- **CRC** &mdash; a CRC-32 checksum computed over the data and LSN
- **Checkpoint flag** &mdash; whether this entry marks a checkpoint

Entries are serialized with `:erlang.term_to_binary/1` and written with a 4-byte little-endian
length prefix. On read, the CRC is recomputed and compared to detect corruption.

## Checkpoints

A checkpoint is a special WAL entry that marks a known-good state. When `Fact.EventLedger` finishes
processing a batch of events, it writes a checkpoint to the WAL containing the current ledger
position.

During recovery, the WAL is read from the most recent checkpoint forward. This means that even if
the WAL contains thousands of historical entries, recovery only needs to process the small tail of
uncommitted work.

## Crash Recovery

Recovery is coordinated by `Fact.EventLedger` at startup:

1. **Repair** &mdash; `Fact.WriteAheadLog.repair/1` is called to truncate any corrupt trailing
   entries from the most recent segment (caused by a partial write during crash)
2. **Replay** &mdash; all entries after the most recent checkpoint are read via
   `Fact.WriteAheadLog.read_all/2`
3. **Reconcile** &mdash; each replayed entry is compared against the ledger. Entries whose position
   exceeds the last known ledger position are re-committed
4. **Checkpoint** &mdash; a new checkpoint is written to mark recovery as complete

This process is automatic and requires no manual intervention.

## Periodic Sync

The WAL maintains a periodic sync timer that flushes the write buffer to disk at the configured
`:sync_interval`. When `:enable_fsync` is `true`, each sync calls `fsync` to guarantee that data
has reached stable storage. This provides a tunable trade-off between write throughput and durability
guarantees.

## Configuration

WAL options are passed through `Fact.open/2` via the `:wal` key:

```elixir
{:ok, db} = Fact.open("data/my_database", wal: [
  enable_fsync: true,
  max_file_size: 16 * 1024 * 1024,
  max_segments: 4,
  sync_interval: 200
])
```

All options are optional and have sensible defaults:

| Option            | Type             | Default      | Description                                               |
|-------------------|------------------|--------------|-----------------------------------------------------------|
| `:enable_fsync`   | `boolean()`      | `true`       | Whether to call fsync when flushing the buffer to disk    |
| `:max_file_size`  | `pos_integer()`  | `16_777_216` | Maximum segment file size in bytes before rotation (16 MB)|
| `:max_segments`   | `pos_integer()`  | `4`          | Maximum number of segment files to retain                 |
| `:sync_interval`  | `pos_integer()`  | `200`        | Milliseconds between periodic sync operations (minimum `10`) |

Options can also be specified when starting databases at supervisor initialization:

```elixir
Fact.Supervisor.start_link(databases: [
  {"/data/high_throughput_db", wal: [enable_fsync: false, sync_interval: 1000]},
  "/data/default_db"
])
```

### Tuning Guidance

**Durability vs. throughput** &mdash; Setting `:enable_fsync` to `false` disables the fsync system
call, which can significantly improve write throughput. However, a power loss or OS crash could
result in data that was acknowledged but not yet flushed to stable storage being lost. Process
crashes within the BEAM are still fully recoverable regardless of this setting.

**Segment size** &mdash; Larger segments reduce the frequency of file rotation but increase the
amount of data that must be scanned during recovery if no checkpoint is present. The default of
16 MB is a reasonable starting point for most workloads.

**Sync interval** &mdash; A shorter interval reduces the window of data at risk during a crash but
increases the number of sync operations per second. A longer interval batches more writes between
syncs, improving throughput at the cost of a larger risk window. The minimum accepted value is
`10`ms; lower values are clamped to `10` to prevent flooding the process mailbox.

## Supervision

The `Fact.WriteAheadLog` process is started and supervised by `Fact.DatabaseSupervisor` as part of
each database's supervision tree. It is registered via `Fact.Registry` under the database's scoped
namespace, ensuring full isolation between multiple database instances.

See the [Process Model](../introduction/process-model.md) guide for an overview of the full
supervision tree.
