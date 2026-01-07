defmodule Fact.Seam.FileReader.Adapter do
  @moduledoc """
  Meta module providing a `Fact.Seam.Adapter` for `Fact.Seam.FileReader` implementations.

  This adapter injects a `read/3` function into the using module that dispatches
  calls to the configured file reader implementation associated with the given context.
  """

  defmacro __using__(opts) do
    context_key = Keyword.fetch!(opts, :context)
    allowed_impls = Keyword.get(opts, :allowed_impls, nil)
    default_impl = Keyword.get(opts, :default_impl, nil)
    fixed_options = Keyword.get(opts, :fixed_options, Macro.escape(%{}))

    quote do
      use Fact.Seam.Adapter,
        registry: Fact.Seam.FileReader.Registry,
        allowed_impls: unquote(allowed_impls),
        default_impl: unquote(default_impl),
        fixed_options: unquote(fixed_options)

      alias Fact.Context

      @key unquote(context_key)

      def read(%Context{@key => instance} = context, path, opts \\ []) do
        __seam_call__(instance, :read, [path, [{:__context__, context} | opts]])
      end
    end
  end
end
