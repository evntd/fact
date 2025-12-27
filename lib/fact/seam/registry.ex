defmodule Fact.Seam.Registry do
  
  @callback all() :: list()
  @callback resolve({atom(), non_neg_integer()}) :: module()
  @callback latest_impl(atom()) :: module()
  @callback latest_version(atom()) :: non_neg_integer()
  @callback implements_behaviours([module()]) :: boolean()
  
  
  defmacro __using__(opts) do
    impls =
      Keyword.fetch!(opts, :impls)
      |> Enum.map(&Macro.expand(&1, __CALLER__))

    latest_versions =
      impls
      |> Enum.group_by(& &1.family())
      |> Enum.map(fn {family, mods} ->
        {family, Enum.max_by(mods, & &1.version())}
      end)
      |> Map.new()

    quote do
      require Logger
      
      @impls unquote(impls)
      @latest_versions unquote(Macro.escape(latest_versions))
      
      
      @behaviour Fact.Seam.Registry
      
      @impl true
      def all(), do: Enum.map(@impls, & &1.id())

      @impl true
      def resolve({family, version} = id)
          when is_tuple(id) and tuple_size(id) == 2,
          do: resolve(family, version)

      def resolve(family, version) do
        Enum.find(@impls, fn impl ->
          impl.family() == family and impl.version() == version
        end) || {:error, {:unsupported_impl, family, version}}
      end

      @impl true
      def latest_impl(family) do
        case Map.get(@latest_versions, family) do
          nil -> {:error, :unsupported_impl}
          impl -> impl
        end
      end

      @impl true
      def latest_version(family) do
        case Map.get(@latest_versions, family) do
          nil -> {:error, :unsupported_impl}
          impl -> impl.version()
        end
      end
      
      @impl true
      def implements_behaviours(behaviours) do
        for impl <- @impls,
            Enum.all?(behaviours, &implements_behaviour?(impl, &1)),
            do: impl.id()
      end
      
      def implements_behaviour?(impl_module, behaviour_module) do
        case Code.ensure_loaded(impl_module) do
          {:module, _} ->
            behaviour_module.behaviour_info(:callbacks)
            |> Enum.all?(fn {name, arity} -> function_exported?(impl_module, name, arity) end)
          {:error, reason} ->
            Logger.error("#{__MODULE__}.implements_behaviour?(#{impl_module}, #{behaviour_module}): unable to load #{reason}")
            false
        end        
      end
    end
  end
end
