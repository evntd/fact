# Getting Started

1. Add `fact` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:fact, "~> 0.1.1"}]
end
```

2. If you are using Elixir `1.17.x` or earlier, add `jason` to support JSON serialization:

```elixir
def deps do
  [
     {:fact, "~> 0.1.1"},
     {:jason, "~> 1.4"}
  ]
end
```

3. Fetch the dependencies:

```sh
$ mix deps.get
```

4. Use mix to create a new database:

```sh
$ mix fact.create -p tmp/factdb
```

5. Test it out via `iex`:

```sh
$ iex -S mix

iex> {:ok, db} = Fact.open("tmp/factdb")

iex> Fact.read(db, :all)
```

6. Add it to your supervision tree:

```elixir
# Inside your Supervisor module's init

children = [
  {Fact.Supervisor, databases: ["tmp/factdb"]}
]

```

7. Lookup the database id by name and used as the handle for operations.

```elixir
# Else where in your code.

{:ok, db} = Fact.Registry.get_database_id("factdb")

```

You've got want you need, check the `Fact` module docs for details on appending, reading, and subscribing.