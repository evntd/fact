defmodule Fact do
  @default_instance_name :""

  def start_link(opts \\ []) do
    Fact.Supervisor.start_link(opts)
  end

  defmacro __using__(opts) do
    instance_name = Keyword.get(opts, :name, @default_instance_name)

    quote do
      @instance_name unquote(instance_name)

      def start_link(opts \\ []) do
        Fact.start_link(Keyword.put(opts, :name, @instance_name))
      end
    end
  end
end
