defmodule Fact do
  @default_instance_name :""

  def start_link(opts \\ []) do
    Fact.Supervisor.start_link(opts)
  end

  def append(instance, events, boundary, append_opts \\ [])

  def append(instance, events, %Fact.EventQuery{} = query, append_opts),
    do: append(instance, events, query, append_opts)

  def append(instance, events, [%Fact.EventQuery{}] = query, append_opts),
    do: Fact.EventQueryWriter.append(instance, events, query, append_opts)

  def append(instance, events, event_stream, append_opts) when is_binary(event_stream),
    do: Fact.EventStreamWriter.append(instance, events, event_stream, append_opts)

  def read(instance, event_source, read_opts \\ []) do
    Fact.EventReader.read(instance, event_source, read_opts)
    |> Stream.map(fn {_, record} -> record end)
  end

  defmacro __using__(opts) do
    instance_name = Keyword.get(opts, :name, @default_instance_name)

    quote do
      @instance_name unquote(instance_name)

      def start_link(opts \\ []) do
        Fact.start_link(Keyword.put(opts, :name, @instance_name))
      end

      def append(events, event_stream_or_query, append_opts \\ []) do
        Fact.append(@instance_name, events, event_stream_or_query, append_opts)
      end

      def read(event_source, read_opts \\ []) do
        Fact.read(@instance_name, event_source, read_opts)
      end
    end
  end
end
