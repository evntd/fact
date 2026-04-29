# Merkle Mountain Range

The **Merkle Mountain Range (MMR)** is an optional, append-only cryptographic data structure that
provides tamper detection and external verification for the event history. It commits to the full
sequence of events in a database, enabling detection of any modification, deletion, reordering, or
insertion of events after the fact.

At a high level:

- Each event becomes a **leaf** in the MMR, linked to the previous leaf by a hash chain
- Internal nodes are computed by hashing pairs of children, forming a tree
- The **peak hashes** of the MMR serve as a compact commitment to the entire event history
- **Inclusion proofs** allow verification of individual events in O(log n) without the full database
- The MMR is **disabled by default** and only activated when configured via `Fact.open/2`

## Why a Merkle Mountain Range?

Fact supports content-addressable storage (CAS) where record filenames are derived from content
hashes. This provides per-file integrity — a corrupt or modified file won't match its name. However,
CAS alone cannot detect:

- **Deletions** — an event file is removed entirely
- **Reordering** — events are rearranged in the ledger
- **Insertions** — new events are injected into the history
- **Selective modification** — an event is replaced with a different event that has a different hash

An MMR solves all of these. Every event is committed to the structure with its content hash, its
ledger position, and a chain link to the previous leaf. Any alteration to the event history changes
the peak hashes, making tampering detectable.

## Threat Model

The MMR is designed to protect against two classes of adversaries:

**Operator tampering** — a database administrator or someone with filesystem access silently
modifies the event history. The MMR detects this at verification time (startup, explicit check,
or via mix tooling).

**External verification** — a third party (auditor, regulator, counterparty) needs to verify that
the event history they received is complete and unaltered. They can compare peak hashes or validate
inclusion proofs independently, without trusting the operator.

## How It Works

### Leaf Hash

Each event produces a leaf hash that commits to three values:

```
leaf_hash = hash(content_hash || position || prev_leaf_hash)
```

- **Content hash** — the CAS record ID, which is the hash of the serialized event data
- **Position** — the event's ledger position (encoded as a 64-bit little-endian integer)
- **Previous leaf hash** — the hash of the preceding leaf, or a zeroed hash for the first event

The previous leaf hash creates a **hash chain** within the MMR leaves. This means that any
insertion, deletion, or reordering of events changes not just one leaf but cascades through all
subsequent leaves.

### Internal Nodes

Internal nodes are computed by hashing the concatenation of their two children:

```
node_hash = hash(left_child || right_child)
```

### Peaks

Unlike a standard Merkle tree, an MMR can have multiple **peaks** — one for each complete binary
subtree. Together, the peak hashes form the root commitment to the entire event history. When a new
leaf is appended, it may merge with existing peaks to form larger subtrees.

### Hash Algorithm

The MMR reuses the same hash algorithm configured for the CAS naming seam. This is determined at
database creation time and can be any of: SHA-1, MD5, SHA-256, SHA-512, SHA3-256, SHA3-512,
Blake2b, or Blake2s.

For integrity guarantees, SHA-256 or stronger is recommended.

## Storage

The MMR is stored as a flat binary file at `<database_path>/merkle/mmr`. Each node occupies exactly
`hash_size` bytes at a deterministic offset:

```
node at position i → byte offset i * hash_size
```

This enables O(1) random access for any node, which is essential for efficient proof generation.
A separate checkpoint file (`merkle/.checkpoint`) tracks the last processed ledger position.

## Out of the Write Path

The MMR operates **asynchronously**, outside the event write path. It subscribes to event
notifications via PubSub (the same mechanism used by indexers) and processes events as they arrive.
This means:

- **Zero impact on write latency** — event writes are not blocked by MMR computation
- **The MMR may briefly lag** behind the ledger, similar to how indexes work
- **On startup**, the MMR catches up from its checkpoint to the current ledger head before
  transitioning to live processing

## Configuration

The MMR is opt-in, configured through `Fact.open/2` via the `:merkle` key. It requires CAS mode
(`record_file_name` configured with `hash@1`).

```elixir
{:ok, db} = Fact.open("data/my_database", merkle: [
  batch_size: 10,
  flush_interval: 1_000
])
```

| Option            | Type            | Default | Description                                            |
|-------------------|-----------------|---------|--------------------------------------------------------|
| `:batch_size`     | `pos_integer()` | `1`     | Maximum events to buffer before flushing to the MMR file |
| `:flush_interval` | `pos_integer()` | `1_000` | Maximum milliseconds before flushing a partial batch     |

A `batch_size` of `1` provides the strongest guarantee — every event is committed to the MMR
immediately. Higher values improve write throughput by batching multiple events into a single
file sync, at the cost of a brief window where the MMR lags behind the ledger.

The `flush_interval` ensures that even under low write volume, buffered events are flushed within
the configured time. This prevents stale buffers when writes are infrequent.

## Verification

### Runtime

`Fact.MerkleMountainRange.verify/1` performs a full verification: it rebuilds the MMR from all
stored events and compares each leaf against the on-disk MMR file. If any discrepancies are found,
it returns the specific leaf positions that were tampered with.

```elixir
iex> Fact.MerkleMountainRange.verify(db)
:ok

iex> Fact.MerkleMountainRange.verify(db)
{:error, :tampered, [42, 43, 44]}
```

### Peak Export

`Fact.MerkleMountainRange.peaks/1` returns the current peak hashes. These can be shared with
auditors for comparison against their own independent computation.

```elixir
iex> Fact.MerkleMountainRange.peaks(db)
{:ok, [<<161, 42, ...>>, <<78, 201, ...>>]}
```

### Inclusion Proofs

`Fact.MerkleMountainRange.create_proof/2` generates a compact proof that a specific event at a
given store position is part of the committed history. The proof contains the sibling hashes
needed to recompute the path from the leaf to its peak.

```elixir
iex> Fact.MerkleMountainRange.create_proof(db, 3)
{:ok, %{
  leaf_index: 2,
  leaf_hash: <<...>>,
  sibling_hashes: [<<...>>, <<...>>],
  peaks: [<<...>>]
}}
```

### Verifying a Proof

`Fact.MerkleMountainRange.verify_proof/2` verifies a proof independently — it does not require
access to the database. It recomputes the hash path from the leaf through the sibling hashes and
checks that the result matches one of the peaks. This allows an external auditor to confirm that
an event is part of the committed history without trusting the operator.

```elixir
iex> {:ok, proof} = Fact.MerkleMountainRange.create_proof(db, 3)
iex> Fact.MerkleMountainRange.verify_proof(proof, :sha256)
:ok
```

If the proof has been tampered with or does not match the peaks, verification fails:

```elixir
iex> Fact.MerkleMountainRange.verify_proof(bad_proof, :sha256)
{:error, :proof_invalid}
```

### Auditor Workflow

The typical workflow for external verification involves three steps:

1. **Operator generates a proof** for a specific event and exports it as JSON:

       mix fact.merkle.create_proof -p data/my_database --position 42 -o proof.json

2. **Operator sends `proof.json`** to the auditor through any channel (email, API, etc.).
   The file is self-contained — it includes the leaf hash, sibling hashes, peaks, and
   the hash algorithm.

3. **Auditor verifies the proof** without needing access to the database:

       mix fact.merkle.verify_proof --proof proof.json

   The auditor can also compare the peaks in the proof against peaks they received
   previously (via `mix fact.merkle.root`) to ensure the operator hasn't replaced the
   entire MMR.

The proof JSON file looks like:

```json
{
  "leaf_index": 2,
  "leaf_hash": "4447e5b1...",
  "sibling_hashes": [
    "39d3f586...",
    "0e595192..."
  ],
  "peaks": [
    "19d6c240...",
    "50d91ace..."
  ],
  "hash_algorithm": "sha256"
}
```

## Mix Tasks

Four mix tasks provide offline verification and inspection:

### `mix fact.merkle.verify`

Rebuilds the MMR from all stored events and compares against the on-disk file. Pinpoints which
store positions have been tampered with.

```sh
mix fact.merkle.verify -p data/my_database
```

### `mix fact.merkle.root`

Prints the current peak hashes for export to auditors.

```sh
mix fact.merkle.root -p data/my_database
```

### `mix fact.merkle.create_proof`

Generates an inclusion proof for the event at a given store position. Use `--output` to write
the proof as a JSON file suitable for sharing with auditors.

```sh
# Print human-readable proof
mix fact.merkle.create_proof -p data/my_database --position 42

# Export as JSON for auditor
mix fact.merkle.create_proof -p data/my_database --position 42 -o proof.json
```

### `mix fact.merkle.verify_proof`

Verifies an inclusion proof from a JSON file. Does not require access to the database.

```sh
mix fact.merkle.verify_proof --proof proof.json
```

## CAS Mode Requirement

The MMR is currently available only when the database's `record_file_name` is configured with the
hash strategy (`hash@1`). In CAS mode, the record ID is already the content hash of the event, so
the MMR leaf hash computation requires no additional hashing of the event content — the record ID
is used directly as the content hash input.

This can be generalized to EventId naming in the future by adding a content hash computation step
during leaf creation.

## Supervision

The `Fact.MerkleMountainRange` process is started and supervised by `Fact.DatabaseSupervisor` as
part of each database's supervision tree. It is registered via `Fact.Registry` under the database's
scoped namespace, ensuring full isolation between multiple database instances.

See the [Process Model](../introduction/process-model.md) guide for an overview of the full
supervision tree.
