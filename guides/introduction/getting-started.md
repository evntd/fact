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