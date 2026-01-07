defmodule Fact.Seam.Encoder.Adapter do
  @moduledoc """
  Meta module that provides an adapter for calling `Fact.Seam.Encoder` implementations.

  This adapter handles resolution of the encoder instance from a context and
  forwards the `encode/3` call to the underlying implementation.
  """
  defmacro __using__(opts) do
    context_key = Keyword.fetch!(opts, :context)
    allowed_impls = Keyword.get(opts, :allowed_impls, nil)
    default_impl = Keyword.get(opts, :default_impl, nil)
    fixed_options = Keyword.get(opts, :fixed_options, Macro.escape(%{}))

    quote do
      use Fact.Seam.Adapter,
        registry: Fact.Seam.Encoder.Registry,
        allowed_impls: unquote(allowed_impls),
        default_impl: unquote(default_impl),
        fixed_options: unquote(fixed_options)

      alias Fact.Context

      @key unquote(context_key)

      def encode(%Context{@key => instance} = context, value, opts \\ []) do
        __seam_call__(instance, :encode, [value, [{:__context__, context} | opts]])
      end
    end
  end
end
