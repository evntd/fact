# Seam Architecture

Fact was built with deliberately designed boundaries to support the natural evolution of software systems.
While no one can predict how future requirements will change, the chosen persistence model; the file-system, has
remained largely stable for 50 years. This stability, combined with decades of mature operating system tooling, makes
Fact databases simpler to operate and maintain than systems built on proprietary formats and specialized tooling.

Even with a stable foundation to build upon, there are several design choices that directly influence performance,
usability, and operational characteristics.

A Fact database manages five types of files.

### Record files

Persistent event files containing predefined system metadata along with consumer domain-specific data and metadata.

### Ledger files

Files that maintain the exact order in which records are appended, serving as the authoritative sequence of events.

### Index files

Files derived from the ledger that provide filtered subsets of its contents. Indexes provide more performant reads by
eliminating the need to repeatedly scan the entire ledger.

### Index checkpoint files

Lightweight files that store a high-water mark for a given indexer, indicating the highest position in the ledger that
has already been processed.

### Lock file

A file containing metadata about a UNIX socket file used as a mutex to prevent multiple independent operating system
processes from writing to the same Fact database concurrently.

Each of these file types has different characteristics, and the Seam architecture defines how they are stored,
named, encoded, decoded, read, and written. This also includes the event schema used in record files as well as the
identifier generation strategies used to uniquely identify events.

## Seams

The `Fact.Seam` module defines the architectural seam used throughout the system to encapsulate variation without
sacrificing consistency. A seam represents a deliberately constrained extension point: a place where behavior may
evolve independently while remaining discoverable, versioned, and interoperable.

At its core, `Fact.Seam` provides a lightweight `__using__/1` macro that establishes a standard contract for all
seam implementations. Each implementation declares a **family** and **version**, forming a stable identity that
allows multiple strategies, or multiple generations of the same strategy, to coexist safely. This makes change explicit
rather than implicit, with the goal of making evolution additive rather than disruptive.

Beyond identification, seams formalize configuration as a first-class concern. Implementations define default options,
option specifications, normalization, validation, and preparation logic in a consistent way. This ensures that all
seams fail fast on invalid configuration, produce predictable internal state, and surface clear errors when
misconfigured.

Seams are intentionally small and mechanical. They do not encode domain logic themselves; instead, they define how a
concern is expressed rather than what the system does. This separation allows Fact to evolve individual characters,
such as record encoding formats or indexing strategies, without requiring invasive changes to the rest of the system.

## Core Seams

Fact defines a small, focused set of seams to control all I/O behavior associated with the files it manages. Each
seam isolates a single axis of variation, such as naming, encoding, or access semantics, so that changes to one concern
do not cascade into others.

The following seams are applied across the five core file types:

* `Fact.Seam.Decoder`
  Defines how raw bytes are interpreted and transformed into in-memory structures.
* `Fact.Seam.Encoder`
  Defines how in-memory structures are serialized into a persistent binary representation.
* `Fact.Seam.FileName`
  Controls file naming conventions, including determinism, ordering, and discoverability.
* `Fact.Seam.FileReader`
  Defines read semantics, including buffering, access modes, and iteration behavior.
* `Fact.Seam.FileWriter`
  Defines write semantics such as append behavior, synchronization guarantees, exclusivity, and write-once
  constraints.

These seams are composed rather than merged, For example, changing an encoding format does not imply a change to file
layout of read strategy.

In addition to per-file concerns, the `Fact.Seam.Storage` seam defines the logical layout of a Fact database on disk.
This includes directory structure and file placement. By isolating the storage layout behind a seam, Fact allows
alternative layouts or future revisions without altering higher-level behavior.

Event records introduce two additional seams that define their identity and structure:

* `Fact.Seam.EventId`
  Defines the strategy used to generate unique, stable event identifiers.
* `Fact.Seam.EventSchema`
  Defines the schema used to persist system metadata alongside consumer domain-specific data and metadata.

Together, these seams ensure the shape, identity, and persistence characters of events are explicit, versioned, and
evolvable. Rather than baking these decision into the core database logic, Fact treats them as first-class, replaceable
components, making change visible, controlled, and safer.

## Seam Instances

While seam implementations define behavior, a seam instance represents a configured realization of that behavior. A
seam instance pairs a specific implementation module with its initialized state, capturing the options and derived
configuration required for runtime use.

In Fact, seam instances are represented by the `Fact.Seam.Instance` structure. Each instance contains two elements:
a reference to the seam implementation module, and the initialized state produced by invoke the module's `init/1`
function. This state is the result of merging defaults, validating options, and preparing configuration according to
the rules defined by the seam.

By separating implementations from instances, Fact avoids conflating capability with configuration. The same seam
implementation may be instantiated multiple times with different options, and multiple versions of an implementation may
coexist simultaneously, each represented by its own instance. This enables fine-grained control over behavior without
introducing global switches or hidden coupling.

Seam instances provide a uniform way for the system to store, pass, and compose configured components. Higher-level
subsystems do not need to understand how a particular seam is configured or initialized; they interact with the
instances as an opaque, well-formed unit. This reduces surface and simplifies orchestration across the system.

## Seam Registries

Seam registries provide the discovery and resolution layer that connects abstract seam definitions to concrete
implementations. While seam implementations define behavior and seam instances capture configuration, registries
establish the system's authoritative view of what implementations exist and which versions are available for a
given seam family.

A seam registry is responsible for enumerating all known implementation of a particular seam, resolving a specific
implementation by its `{family, version}` identity, and identifying the latest available version for a family. This
allows Fact to make version-aware decisions without hard-coding implementation modules or relying on implicit defaults.

Registries are generated using the `Fact.Seam.Registry` macro. When a registry is defined, it is initialized with a
static set of implementation modules. For this set, the registry derives a complete inventory of supported
implementations as well as a deterministic mapping of the latest version per family. These structures are computed at
compile time, ensuing fast, predictable resolution at runtime.

By centralizing implementation knowledge, seam registries serves as a source of truth of compatibility and evolution.
Components that need a specific behavior can request an explicit `{family, version}`, while others may intentionally
opt into the latest available implementation. In both cases, the decision is explicit, inspectable, and validated
against the registry's known set.

## Seam Adapters

Seam adapters provide the integration layer that binds seam definitions, registries, implementations, and configuration
into a usable runtime component. Where seam implementations define behavior, seam instances capture configuration, and
registries define availability, adapters are responsible for making a concrete, valid choice and exposing it to the rest
of the system.

A seam adapter defines the policy for a particular seam. This includes which implementations are allowed, which
implementation is the default, which options are fixed and cannot be overridden, and how user-supplied configuration is
normalized and validated. By centralizing these decisions, Fact ensures that subsystems interact only with supported,
well-formed seam instances.

Adapters rely on the seam’s registry to resolve implementation modules by {family, version} and to enforce
compatibility. Default and allowed implementations are declared explicitly, preventing accidental use of unsupported or
experimental variants. When multiple implementations are available, adapters make the default choice explicit and fail
fast if ambiguity exists.

Configuration flows through the adapter in a deliberate sequence. Fixed options are applied first, followed by
implementation defaults and finally user-supplied options. Only options recognized by the target implementation are
permitted, and all options are normalized before initialization. The result is a fully initialized Fact.Seam.Instance
containing both the implementation module and its validated state.

Seam adapters also define the dispatch boundary between Fact subsystems and seam implementations. The __seam_call__/3
helper provides a uniform mechanism for invoking functions on a configured seam instance, passing the instance state
as the first argument. This avoids leaking implementation details into higher-level code and preserves a consistent
calling convention across all seams.

Each seam, representing a distinct axis of variation, define its own adapter and registry. The registry enumerates all
known implementations for that seam and establishes version awareness, while the adapter define how those
implementations may be selected, configured, and invoked within the system. This pairing localizes all knowledge about
*what can vary* and *how it is allowed to vary* to the seam itself, preventing cross-cutting configuration logic
from leaking into unrelated subsystems.

In practice, this results in seam-specific adapter and registry modules such as `Fact.Seam.FileReader.Adapter` and
`Fact.Seam.FileReader.Registry`. The registry declares the universe of supported file reader implementations, while
the adapter contains that universe, selects defaults, applies fixed options, and exposes a seam-appropriate dispatch
function. Fact subsystems interact only with the adapter's surface API, never with the underlying implementations
directly. This preserves encapsulation while ensuring that calls are routed through a fully configured, versioned
seam instance.

## Conclusion

The Seam Architecture is the structural foundation that allows Fact to evolve without eroding correctness, operability,
or clarity. By treating variation as an explicit, first-class concern, Fact avoids the hidden coupling and implicit
behavior that typically accumulate in long-lived systems.

Each seam defines a single, well-bounded axis of variation. Implementations encode behavior, instances capture
configuration, registries establish availability and versioning, and adapters enforce policy and provide safe,
uniform access. Together, these pieces form a complete lifecycle for change: from design-time extensibility to
runtime enforcement.

Crucially, this architecture does not rely on global switches, ad hoc configuration, or undocumented conventions. Every
decision: what can vary, how it is configured, which versions are allowed, and how it is invoked—is explicit, versioned,
validated, and inspectable. This makes change visible rather than accidental, and evolution additive rather than
destructive.

The intended result is a system that can grow in capability without growing fragile. New file formats, encoding
strategies, indexing behaviors, or storage layouts can be introduced alongside existing ones. Operational
characteristics can change without rewriting history. Fact’s persistence model remains transparent and tool-friendly,
while its internal behavior adapts deliberately over time.

In short, seams are how Fact reconciles stability with change. They provide the discipline necessary to build databases
that are not only correct today, but understandable, operable, and evolvable for years to come.