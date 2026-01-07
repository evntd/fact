defmodule Fact.Seam.FileWriter.Adapter do
  @moduledoc """
  Meta module providing the adapter interface for `Fact.Seam.FileWriter`.

  Handles dispatching calls to the configured file writer implementation for a given context.
  """
  defmacro __using__(opts) do
    context_key = Keyword.fetch!(opts, :context)
    allowed_impls = Keyword.get(opts, :allowed_impls, nil)
    default_impl = Keyword.get(opts, :default_impl, nil)
    fixed_options = Keyword.get(opts, :fixed_options, Macro.escape(%{}))

    quote do
      use Fact.Seam.Adapter,
        registry: Fact.Seam.FileWriter.Registry,
        allowed_impls: unquote(allowed_impls),
        default_impl: unquote(default_impl),
        fixed_options: unquote(fixed_options)

      alias Fact.Context

      @key unquote(context_key)

      def write(%Context{@key => instance} = context, path, value, options \\ []) do
        __seam_call__(instance, :write, [path, value, [{:__context__, context} | options]])
      end
    end
  end
end
