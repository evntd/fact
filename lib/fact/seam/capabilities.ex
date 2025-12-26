defmodule Fact.Seam.Capabilities do
  defmacro __before_compile__(env) do
    behaviours = Module.get_attribute(env.module, :behaviour) || []

    capabilities =
      behaviours
      |> Enum.filter(&String.starts_with?(Atom.to_string(&1), "Elixir.Fact.Seam.Capability."))
      |> Enum.map(fn behaviour ->
        behaviour
        |> Atom.to_string()
        |> String.split(".")
        |> List.last()
        |> Macro.underscore()
        |> String.to_atom()
      end)

    quote do
      @capabilities unquote(capabilities)
      
      @impl true
      def capabilities(), do: @capabilities

      @impl true
      def capability?(val), do: val in @capabilities
    end
  end
end
