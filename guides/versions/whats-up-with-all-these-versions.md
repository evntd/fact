# What’s Up With All These Versions?

The Fact system tracks multiple versions to keep everything consistent and compatible. Each version covers a different
part of the database — from the engine that runs it, to records, indexes, storage layout, and metadata. By versioning
these components, the system can evolve safely, support migrations, and ensure all data is interpreted correctly.

## Engine Version

The **engine version** identifies the version of the Fact system’s application code that created or manages the
database. It ensures operations and migrations run under a compatible engine.

## Record Version

The **record version** defines the format of individual persistent records (events) stored in the database. It specifies
the schema, encoding, and conventions needed for consistent serialization and deserialization.

## Index Version

The **index version** defines the format of all index data produced by the system’s indexers, including the event
ledger. It ensures indexes are structured and interpreted consistently across database versions.

## Manifest Version

The **manifest version** captures the database’s metadata at creation. It includes component versions, storage layout,
file formats, indexing schemes, and other configuration details the system relies on for correct operation.

## Storage Version

The **storage version** describes the logical organization of the database on disk, including directories, file names,
formats, and encoding schemes. It specifies how the system expects data to be arranged and accessed.

## Operating System Version

The **operating system version** identifies the OS and version under which the database was created or managed. It
provides environmental context that can be useful for diagnostics, troubleshooting, and ensuring platform compatibility.

## OTP Version

The **OTP version** specifies the version of the Erlang/OTP runtime in use when the database was created or accessed. It
ensures compatibility with runtime behaviors, libraries, and concurrency semantics that the system depends on.

## Elixir Version

The **Elixir version** identifies the version of the Elixir language runtime used by the Fact system. It provides
context for language-level features, standard library behavior, and compilation semantics that may affect database
operation or migration.