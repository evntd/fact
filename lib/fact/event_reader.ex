defmodule Fact.EventReader do
  use Fact.EventKeys
  alias Fact.Paths
  require Logger

  def read_all(opts \\ []) do
    from_pos = Keyword.get(opts, :from_position, 0)
    events_path = Paths.events()

    Fact.EventLedger.stream!()
    |> Stream.map(&Path.join(events_path, "#{&1}.json"))
    |> Stream.with_index(1)
    |> Stream.drop_while(fn {_path, pos} -> pos <= from_pos end)
    |> Stream.map(fn {path, _pos} -> path |> File.read!() |> JSON.decode!() end)
  end

  def read_stream(event_stream, opts \\ []) do
    from_pos = Keyword.get(opts, :from_position, 0)
    events_path = Paths.events()

    Fact.EventIndexerManager.stream(Fact.EventStreamIndexer, event_stream)
    |> Stream.map(&Path.join(events_path, "#{&1}.json"))
    |> Stream.with_index(1)
    |> Stream.drop_while(fn {_path, pos} -> pos <= from_pos end)
    |> Stream.map(fn {path, pos} ->
      {:ok, encoded} = File.read(path)
      {:ok, event} = JSON.decode(encoded)
      Map.put(event, @event_stream_position, pos)
    end)
  end

  def read_query(query, opts \\ [])
  def read_query(%Fact.EventQuery{} = query, opts), do: read_query([query], opts)

  def read_query([%Fact.EventQuery{} | _] = query, opts) when is_list(query) do
    from_pos = Keyword.get(opts, :from_position, 0)
    events_path = Paths.events()

    Fact.EventQuery.execute(query)
    |> Stream.map(&Path.join(events_path, "#{&1}.json"))
    |> Stream.map(fn path -> path |> File.read!() |> JSON.decode!() end)
    |> Stream.drop_while(fn e -> e[@event_store_position] <= from_pos end)
  end
end
