defmodule Fact.Seam.Decoder.Adapter do
  @moduledoc """
  Meta module providing an adapter for dispatching to decoder implementations.

  Wraps calls to the underlying `Fact.Seam.Decoder` implementations and handles context injection.
  """

  defmacro __using__(opts) do
    context_key = Keyword.fetch!(opts, :context)
    allowed_impls = Keyword.get(opts, :allowed_impls, nil)
    default_impl = Keyword.get(opts, :default_impl, nil)
    fixed_options = Keyword.get(opts, :fixed_options, Macro.escape(%{}))

    quote do
      use Fact.Seam.Adapter,
        registry: Fact.Seam.Decoder.Registry,
        allowed_impls: unquote(allowed_impls),
        default_impl: unquote(default_impl),
        fixed_options: unquote(fixed_options)

      alias Fact.Context

      @key unquote(context_key)

      def decode(%Context{@key => instance} = context, value, opts \\ []) do
        __seam_call__(instance, :decode, [value, [{:__context__, context} | opts]])
      end
    end
  end
end
