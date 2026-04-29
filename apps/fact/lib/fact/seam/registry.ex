defmodule Fact.Seam.Registry do
  @moduledoc """
  Provides a registry for all implementations of a configurable `Fact.Seam` component. 📚

  A `Fact.Seam.Registry` is responsible for:

    * Listing all available implementations (`all/0`)
    * Resolving a specific implementation by `{family, version}` (`resolve/1` or `resolve/2`)
    * Returning the latest implementation for a family (`latest_impl/1`)
    * Returning the latest version number for a family (`latest_version/1`)

  ## Usage

  When a module `use`s `Fact.Seam.Registry`, it generates:

    * A static list of all known implementations
    * A map of the latest version per family
    * Convenience functions to resolve specific versions or get the latest

  This registry is key for the system's configurable architecture, allowing
  different components to be swapped, upgraded, or resolved dynamically
  without changing the core system logic.

  Essentially, this module provides the source of truth for what implementations exist,
  their versions, and which one is considered the latest for a given family.
  """

  @callback all() :: list()
  @callback resolve({atom(), non_neg_integer()}) :: {:ok, module()} | {:error, term()}
  @callback latest_impl(atom()) :: module()
  @callback latest_version(atom()) :: non_neg_integer()

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
        resolved =
          Enum.find(@impls, fn impl ->
            impl.family() == family and impl.version() == version
          end)

        if is_nil(resolved),
          do: {:error, {:unsupported_impl, family, version}},
          else: {:ok, resolved}
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
    end
  end
end
