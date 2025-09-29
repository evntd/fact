# Fact

A file system based event store to maximize interoperability and portability.

## Features

| Feature                            | Description                                                                         |
|------------------------------------|-------------------------------------------------------------------------------------|
| **Static consistency boundaries**  | Common stream based approach for managing context boundaries using DDD aggregates.  |
| **Dynamic consistency boundaries** | A simple, flexible approach for managing context boundaries using query conditions. |
| **Optimistic concurrency control** | Positional expectations to prevent dirty writes.                                    |
| **Indexing**                       | Indexing by type, stream, stream category, tag, and data properties.                |
| **Content Addressable Storage**    | Configurable option to detect tampering.                                            |
| **Multiple Instances**             | Support for multitenancy systems requiring silo isolation.                          |

## Installation

The package can be installed by adding `fact` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:fact, "~> 0.0.1"}
  ]
end
```



