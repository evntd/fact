# Queries and Indexing in Fact

This guide explains how **Queries** are implemented in Fact and how they enable **Dynamic Consistency Boundaries (DCB)**
using a filesystem-based indexing model. It is intended for developers using Fact directly, as well as those exploring
its internal design.

At a high level:

- Queries are **purely index-driven**
- Indexes are **append-only, ordered sets**
- Query execution relies on **set algebra plus a ledger scan**
- No event payloads are read during query evaluation

This design keeps queries predictable, explainable, and efficient while preserving Fact’s core guarantees.

## Dynamic Consistency Boundaries

Fact implements the DCB specification by allowing Queries to be defined in terms of:

- **Event tags**
- **Event types**
- **Event data fields** (a Fact extension)

Each query describes a *consistency boundary* by selecting a subset of events that match one or more conditions. These
conditions are resolved entirely through Fact’s indexing subsystem.

## The Indexing Model

Fact maintains a set of **append-only index files** that act as precomputed, ordered sets of event record IDs.

An **event record ID** is a **unique identifier for an event record file** stored within the `/events/` directory
hierarchy. It is not a byte offset or position in the ledger. Instead, it provides a stable reference to a specific
event record on disk.

Indexes never store event payloads — only event record IDs.

All index files are ordered by the event’s **store position**, which represents the event’s logical ordering within the
system.

## Event Tag Indexer

**Module:** `Fact.EventTagsIndexer`

For every tag defined in the system, Fact maintains a corresponding index file at:

`/indices/event_tags/<tag>`

Each file contains:

- A list of event record IDs
- Ordered by the event’s store position

Example:

`/indices/event_tags/admin`

This file represents all events tagged `admin`, ordered by store position.

## Event Type Indexer

**Module:** `Fact.EventTypeIndexer`

For every event type defined in the system, Fact maintains a corresponding index file at:

Example:

`/indices/event_type/user_created`

This file represents all `user_created` events, ordered by store position.

## Event Data Indexers

**Module:** `Fact.EventDataIndexer`

Event data indexing is more granular and more flexible.

- There may be many event data indexers
- Each indexer targets a single key within the event’s data payload

For example, an indexer for the `name` field creates files under:

```
/indices/event_data/name/
```

Each distinct value of that field results in its own index file:

```sh
/indices/event_data/name/Alice
/indices/event_data/name/Bob
```

Each file contains:

- A list of event record IDs
- Ordered by the event’s store position
- Representing events where `data.name == <value>`

This structure allows Fact to efficiently answer queries like:

All events where `name == "Alice"` without scanning event payloads.

## Index Files as Ordered Sets

Conceptually, every index file represents a precomputed, ordered set of event record IDs
matching a single condition.

Examples include:

- Tag = `admin`
- Type = `user_created`
- Data field `name = "Alice"`

## Query Execution Model

Queries are evaluated by combining index files using set operations, followed by a ledger scan to restore ordering.

### Step 1: Load Index Sets

For each query condition:

- Fact reads one index file
- Each file is loaded as a set of event record IDs

This produces a collection of ordered sets.

**Cost:**

- 1 file read per condition
- O(N) per index

### Step 2: Apply Set Algebra

Fact combines these sets using standard set operations:

- AND → `MapSet.intersection/2`
- OR → `MapSet.union/2`

#### Complexity

| Operation          | Worst Case   | Best Case    |
|--------------------|--------------|--------------|
| Intersection (AND) | O(min(N, M)) | Ω(1)         |
| Union (OR)         | O(N + M)     | Ω(min(N, M)) |

Because index sizes can vary significantly, small or highly selective indexes dramatically improve performance,
particularly when used early in an AND chain.

### Step 3: Restore Ledger Ordering

After set operations, the resulting set of event record IDs is unordered.

To restore the correct ordering, Fact performs a single linear scan of the ledger:

- Starting from `:start` or from a specified ledger position
- Applying a predicate:
    - “Does this ledger entry reference an event record ID present in the computed result set?”

This uses `MapSet.member?/2` which has Ω(1) for result sets contains 32 or less elements, otherwise is O(log n).

This produces the final ordered stream of event record IDs.

**Cost:**

- One ledger scan
- O(N)

## No Event Reads During Queries

A key property of Fact queries is that:

> No event records are read from disk during query execution

Only the following are accessed:

- Index files
- The ledger file (event record IDs only)

Event payloads are read only after query evaluation, and only if the caller explicitly consumes them.

## Performance Characteristics

Overall query complexity consists of:

- O(N) index reads
- O(N) ledger scan
- Plus the cost of set operations based on index sizes

### Practical Performance Considerations

Query performance improves when:

- Indexes are highly selective
- Queries include small index sets
- Ledger scans start from a known position rather than `:start`

In practice, most queries operate on a small subset of the total event space.

## Why This Design Works

This design provides several important properties:

- Deterministic behavior — no hidden planners or heuristics
- Explainable performance — costs are explicit and predictable
- Composable consistency boundaries — built from simple primitives
- Tool-friendly storage — index files are plain, inspectable data

Queries in Fact are not magic. They are explicit set operations over durable, append-only structures, grounded directly
in the event ledger and filesystem.

## Worked Examples

This example demonstrates how Fact evaluates queries using index files, set operations, and a ledger scan. The same
event set is used for both queries to illustrate how AND and OR combinations affect execution. No event payloads are
read during query evaluation.

Assume the system contains the following events:

| Store Position | Event Record ID | Type         | Tags      | Data                  |
|----------------|-----------------|--------------|-----------|-----------------------|
| 1              | e1              | user_created | [admin]   | { "name": "Alice" }   |
| 2              | e2              | user_created | []        | { "name": "Bob" }     |
| 3              | e3              | user_deleted | [admin]   | { "name": "Alice" }   |
| 4              | e4              | user_created | [support] | { "name": "Alice" }   |
| 5              | e5              | user_updated | [admin]   | { "name": "Charlie" } |

The store position represents the event’s logical ordering within the system. Each event record ID corresponds to a
unique file under the `/events/` directory hierarchy.

The following index files exist. All index files are ordered by store position.

Event tag index for `admin`

```sh
#/indices/event_tags/admin
e1
e3
e5
```

Event tag index for `support`

```sh
#/indices/event_tags/support
e4
```

Event type index for `user_created`

```sh
#/indices/event_type/user_created
e1
e2
e4
```

Event data index for `name = "Alice"`

```sh
#/indices/event_data/name/Alice
e1
e3
e4
```

### Query 1

Select all the events where the tag is `admin`, the type is `user_created`, and the data field `name` equals `Alice`.

```elixir
iex> import Fact.QueryItem
iex> query1 = tags("admin") |> types("user_created") |> data(name: "Alice")
```

The query loads one index file per condition, producing the following sets:

```
admin → { e1, e3, e5 }  
user_created → { e1, e2, e4 }  
name = "Alice" → { e1, e3, e4 }
```

The sets are combined using intersections (AND):

```
{ e1, e3, e5 } ∩ { e1, e2, e4 } = { e1 }  
{ e1 } ∩ { e1, e3, e4 } = { e1 }
```

The final result set is:

```
{ e1 }
```

Fact then performs a single ledger scan starting from `:start`. As each ledger entry is encountered, its event record ID
is checked for membership in the result set. Only `e1` matches, producing the final ordered result:

```
e1
```

#### Query 2

Select all events where the tag is `admin` OR `support` OR the type is `user_created`.

```elixir
iex> import Fact.QueryItem
iex> join([tags("admin"), tags("support"), types("user_created")])
```

The query loads the following index sets:

```
admin → { e1, e3, e5 }  
support → { e4 }  
user_created → { e1, e2, e4 }
```

First, the OR condition is evaluated using a union:

```
{ e1, e3, e5 } ∪ { e4 } = { e1, e3, e5, e4 }
```

Next, the second OR condition is applied:

```
{ e1, e3, e5, e4 } ∪ { e1, e2, e4 } = { e1, e3, e5, e4, e2 }
```

The final result set is:

```
{ e1, e3, e5, e4, e2 }
```

Fact performs a single ledger scan to restore ordering:

| Store Position | Event Record ID | In Result Set |
|----------------|-----------------|---------------|
| 1              | e1              | yes           |
| 2              | e2              | yes           |
| 3              | e3              | yes           |
| 4              | e4              | yes           |
| 5              | e5              | yes           |

The final ordered result is:

```
e1
e2
e3
e4
e5
```

### Key Observations

- Exactly **one file read per query condition**
- Exactly **one ledger scan**
- No event payloads were read
- Ordering is derived from the ledger, not the indexes
- Index files are reused across all queries

---

### Why This Matters

This execution model ensures that queries in Fact are:

- Deterministic and explainable
- Independent of event payload size
- Safe to compose into Dynamic Consistency Boundaries
- Efficient even as the event store grows

Queries select *which* events belong to a consistency boundary.  
The ledger defines *when* those events occurred.