defmodule Fact.Seam.Registry do
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
      @impls unquote(impls)
      @latest_versions unquote(Macro.escape(latest_versions))

      def all(), do: Enum.map(@impls, & &1.id())

      def resolve({family, version} = id)
          when is_tuple(id) and tuple_size(id) == 2,
          do: resolve(family, version)

      def resolve(family, version) do
        Enum.find(@impls, fn impl ->
          impl.family() == family and impl.version() == version
        end) || {:error, {:unsupported_impl, family, version}}
      end

      def latest_impl(family) do
        case Map.get(@latest_versions, family) do
          nil -> {:error, :unsupported_impl}
          impl -> impl
        end
      end

      def latest_version(family) do
        case Map.get(@latest_versions, family) do
          nil -> {:error, :unsupported_impl}
          impl -> impl.version()
        end
      end
    end
  end
end
