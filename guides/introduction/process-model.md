# Process Model

Fact is designed around a multi-database architecture. Rather than sharing a single
global runtime, each database operates as an independent unit with its own supervision
tree (`Fact.DatabaseSupervisor`). This improves fault-tolerance, operational isolation,
and scalability. A failure in one database does not affect the others.

![Fact Process Model](/guides/assets/images/process-model.svg)

With each database supervision tree, Fact supervises a core set of GenServer processes:

* `Fact.Database`
* `Fact.EventLedger`
* `Fact.PubSub` (which is a `Phoenix.PubSub` process)

Its own set of indexer processes:

* `Fact.EventTypeIndexer`
* `Fact.EventTagsIndexer`
* `Fact.EventStreamIndexer`
* `Fact.EventStreamCategoryIndexer`
* `Fact.EventStreamsIndexer`
* `Fact.EventStreamsByCategoryIndexer`
* `Fact.EventDataIndexer`

> #### About Event Data Indexers {: .warning}
>
> These GenServer processes are started on demand when required to fulfill event queries.
> Once started, they remain alive under supervision and continue to process and index
> new events like any other indexer.
>
> It is much more performant to model your system with queries which only utilize tags and types.
> Data queries are a convenience feature to use when a tag or type was missed during design, or
> your iterating on a new feature.

In addition, Fact includes `Fact.EventStreamWriterSupervisor`, a dynamic supervisor responsible
for supervising `Fact.EventStreamWriter` processes. Each `Fact.EventStreamWriter` is a GenServer
that enforces and maintains the consistency boundary for an individual event stream, providing
ordered writes, optimistic concurrency control, and stream-specific event enrichment.

The event stream writer processes are started on demand and gracefully terminate after a period
of inactivity (approximately 1 minute), minimizing resource usage while still preserving consistency
guarantees when active.
