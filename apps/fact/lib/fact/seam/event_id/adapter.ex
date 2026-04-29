defmodule Fact.Seam.EventId.Adapter do
  @moduledoc """
  Meta module providing an adapter for `Fact.Seam.EventId` implementations.

  Provides a unified interface for generating event IDs across different implementations,
  allowing initialization and delegation via the `Fact.Seam.Adapter` system.
  """

  defmacro __using__(opts) do
    context_key = Keyword.fetch!(opts, :context)
    allowed_impls = Keyword.get(opts, :allowed_impls, nil)
    default_impl = Keyword.get(opts, :default_impl, nil)
    fixed_options = Keyword.get(opts, :fixed_options, Macro.escape(%{}))

    quote do
      use Fact.Seam.Adapter,
        registry: Fact.Seam.EventId.Registry,
        allowed_impls: unquote(allowed_impls),
        default_impl: unquote(default_impl),
        fixed_options: unquote(fixed_options)

      alias Fact.Context

      @key unquote(context_key)

      def generate(database, opts \\ [])

      def generate(database_id, opts) when is_binary(database_id) do
        with {:ok, context} <- Fact.Registry.get_context(database_id) do
          generate(context, opts)
        end
      end

      def generate(%Context{@key => instance} = context, opts) do
        __seam_call__(instance, :generate, [[{:__context__, context} | opts]])
      end
    end
  end
end
